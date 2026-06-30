# Smart Contract Subsystem Architecture & Lifecycle Specification

This specification covers the implementation, structure, and operational lifecycle of the EIP-2535 Diamond Standard smart contracts within the `./smart-contracts` workspace of the monorepo. This subsystem handles tokenization, media access management, and asset gating configurations, fully upgraded to Hardhat 3, ECMAScript Modules (ESM), and containerized testing standards.

---

## 1. Architectural Overview (EIP-2535 Diamond Standard)

To maintain feature scalability, bypass the 24KB Ethereum smart contract size limitation, and lower deployment overhead, this project implements a customized implementation of the EIP-2535 Diamond Standard utilizing the `@solidstate/contracts` package. Instead of deploying large standalone monolithic contracts, functionalities are broken down into logical modules known as **Facets**. All external execution requests flow through a central proxy router known as the **Diamond Proxy**.

```text
                  Incoming User Transaction / RPC Fetch
                                   │
                                   ▼
                   ┌───────────────────────────────┐
                   │    Diamond Proxy Contract     │
                   │  (Factory / Marketplace Addr) │
                   └───────────────┬───────────────┘
                                   │
                    Fallback Delegatecall Routing
                                   │
         ┌─────────────────────────┼─────────────────────────┐
         ▼                         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   Admin Facet   │       │ Deployer Facet  │       │  Points Facet   │
│  (Token/Source) │       │ (Clone Spawner) │       │ (Deposit/Withd) │
└─────────────────┘       └─────────────────┘       └─────────────────┘

```

### 1.1 The Dynamic Pointer Pull Gateway

To completely eliminate the multi-hop factory routing overhead during `fallback()` execution while preserving global upgradeability, deployed child collections implement a **Cached Gateway Pointer**:

1. **Deployment Binding:** At birth, the spawner reads the master `facetSource` reference address from the factory state and permanently commits it into the individual clone's hashed storage slot `rair.contracts.storage.RAIR721`.
2. **Read-Only / State Execution Routing:** When an external service triggers the fallback routine, the clone fetches the absolute implementation address by reading `IDiamondReadable(facetSource).facetAddress(msg.sig)`. This read-only step runs seamlessly in static block lookups (e.g., OpenSea querying `tokenURI`) and saves significant gas on state-mutating block transactions.

---

## 2. Directory Layout & Consolidation Matrix

The project structure is split into core domains. Historical multi-facet systems have been streamlined and merged into cohesive execution facets to decrease production code sizes and optimize memory footprints:

```text
.
├── contracts/
│   ├── Factory/
│   │   ├── AccessControlRoles.sol
│   │   ├── AppStorage.sol              <-- Unified Hashed Storage Layout
│   │   ├── FacetSource.sol             <-- Master Core Router Proxy
│   │   ├── FactoryDiamond.sol          <-- Spawner Proxy Entrypoint
│   │   └── facets/
│   │       ├── FactoryAdminFacet.sol   <-- Merged Administrations & Setters
│   │       ├── FactoryDeployerFacet.sol <-- Handles Clone Deployments & Registry
│   │       └── FactoryPointsFacet.sol   <-- Consolidated Points, Deposits & Signatures
│   ├── Marketplace/
│   │   ├── AppStorage.sol              <-- Collision-Safe Marketplace Layout
│   │   ├── MarketplaceDiamond.sol
│   │   ├── Storage/
│   │   │   └── ResaleStorage.sol
│   │   └── Facets/
│   │       ├── MarketplaceAdminFacet.sol <-- Consolidated Fees & MultiSend Operations
│   │       ├── MintingOffersFacet.sol  <-- Primary Sale Allocations & Math Routing
│   │       └── ResalesFacet.sol         <-- P2P Resale Orders & Signed Handshakes
│   ├── common/
│   │   ├── DiamondStorage/
│   │   │   ├── AccessControlEnumerable.sol <-- Houses Global DEFAULT_ADMIN_ROLE (0x00)
│   │   │   └── AccessControlEnumerableStorage.sol
│   │   └── SignedHashProtection.sol     <-- Cryptographic Signature Validation
│   ├── exchange/
│   │   └── ERC20Exchange.sol            <-- Isolated License Minting Exchange
│   ├── tokens/
│   │   ├── IERC2981.sol
│   │   ├── RAIR-721/                    <-- Universal Multi-Service Media Clones
│   │   │   ├── AccessControlRoles.sol
│   │   │   ├── AppStorage.sol          <-- Contains cached gateway fields
│   │   │   ├── RAIR-ERC721.sol         <-- Gas-Optimized Fallback proxy
│   │   │   └── Facets/
│   │   └── RAIR-ERC20.sol               <-- Standard Mintable Burnable Asset
│   └── maliciousContracts/             <-- Security Regression Sanity Components
└── test/                                <-- Snapshot-Driven Testing Engine

```

---

## 3. Storage Architecture & Upgrade Rules

To protect upgradeable proxy systems from data corruption, standard top-level state declarations are forbidden in diamond proxies and facets. Instead, all structures rely exclusively on **AppStorage Appended Diamond Storage Mapping Slots** via explicit assembly pointers.

### 3.1 Namespace Pointer Allocations

Every subsystem isolates its state fields behind a unique, precalculated string identifier hash to prevent accidental namespace collisions:

* **Factory State Slot:** `keccak256("rair.contracts.storage.DiamondFactory")`
* **Access Enumerable Slot:** `keccak256("rair.contracts.storage.AccessControlEnumerable")`
* **Marketplace App Slot:** `keccak256("rair.contracts.storage.MarketplaceApp")`
* **P2P Resale Order Slot:** `keccak256("rair.contracts.storage.resaleOffers")`
* **RAIR721 Token Slot:** `keccak256("rair.contracts.storage.RAIR721")`

### 3.2 Storage Struct Layout Extension Protocol

When upgrading a sub-system layout, existing struct members **must never be reordered, modified, or removed**. New properties can only be appended to the absolute end of the target struct definition.

```solidity
struct Layout {
    string baseURI;
    address factoryAddress;
    address facetSource; // Appended during Gateway Refactor
    uint16 royaltyFee;
    // ... Existing mappings ...
    bool requiresTrader; // Appended to resolve evaluation lookups safely
}

```

---

## 4. Security Framework & Value Routings

### 4.1 Global Native Value Transfers (`.call` Security Protocol)

Due to the strict 2,300 gas stipend limits imposed by the legacy `.transfer()` function (which fails when interacting with smart contract wallets like Safe multi-sigs), all native value distributions across `MintingOffersFacet.sol` and `ResalesFacet.sol` have been migrated to the secure low-level `.call` instruction:

```solidity
(bool success, ) = payable(recipient).call{value: amount}("");
require(success, "Transfer failed");

```

Reentrancy attacks are mitigated by executing all internal accounting updates (e.g., deducting point balances, tracking sold state markers) *before* invoking this external transfer call, following the strict Checks-Effects-Interactions pattern.

### 4.2 Cryptographic Handshakes

Peer-to-peer marketplace order fulfillments and points-based credit withdrawals utilize gasless signed authorizations off-chain. The smart contract validates these on-chain via `SignedHashProtection.sol`. The validation flow requires rounding expiration intervals to 100-second block intervals to prevent transaction front-running and replay attacks.

---

## 5. Testing Framework Specification (Modular Snapshots)

The monolithic testing framework (`diamonds.js`) has been replaced by an enterprise-grade **Modular Fixture Architecture** powered by `@nomicfoundation/hardhat-network-helpers`.

Instead of running slow contract deployments before every test case, the test engine utilizes a single global deployment pipeline (`test/helpers/setup.js`). Hardhat takes a structural snapshot of the clean blockchain state immediately after creating the diamonds. Before each individual test executes, the network state instantly rolls back to that snapshot in memory.

### 5.1 Test Execution Commands

* **Run Entire Suite:** `npm run test`
* **Target Factory Modules:** `npx hardhat test test/01_Factory.test.js`
* **Target Marketplace Rules:** `npx hardhat test test/02_Marketplace.test.js`
* **Verify Full End-to-End Lifecycle:** `npx hardhat test test/04_RAIR721_Lifecycle.test.js`

---

## 6. Local Node Provisioning & Infrastructure Lifecycle

For development cycles, the local blockchain state runs inside the monorepo's shared virtualization cluster via `docker-compose.local-new.yml`. This decouples the development workspace from public testnets.

### 6.1 Container Engine Specifications

The local chain infrastructure is managed by a containerized **Anvil** engine instance. It functions as a fast, zero-fee local ledger that exposes an isolated Web3 JSON-RPC interaction gateway.

```yaml
  evm-node:
    container_name: evm-node
    image: ghcr.io/foundry-rs/foundry:latest
    ports:
      - 8545:8545
    command: anvil --host 0.0.0.0
    networks:
      - local-network

```

### 6.2 Command Reference Manual

Execute these management operations from within the `./smart-contracts/` directory workspace:

#### Compile Contracts and Dispatch Updated ABIs

```bash
npm run build

```

#### Execute Local Unit Testing Suite

```bash
npm run test

```

#### Run Diamond Deployments and Cuts Against Local Node Container

```bash
npx hardhat deploy --network localhost

```