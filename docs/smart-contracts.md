# Smart Contract Subsystem Architecture Specification

This specification covers the implementation, structure, and operational lifecycle of the EIP-2535 Diamond Standard smart contracts within the `./smart-contracts` workspace of the monorepo. This subsystem handles tokenization, media access management, and asset gating configurations.

---

## 1. Architectural Overview (EIP-2535 Diamond Standard)

To maintain feature scalability, bypass the 24KB Ethereum smart contract size limitation, and lower deployment overhead, this project implements the EIP-2535 Diamond Standard. Instead of deploying large standalone monolithic contracts, functionalities are broken down into logical modules known as **Facets**. All external execution requests flow through a central proxy router known as the **Diamond Proxy**.

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
│  TokensFacet    │       │RAIRProductFacet │       │RAIRMetadataFacet│
│ (Mint/Balances) │       │ (Product/Gating)│       │(URI Management) │
└─────────────────┘       └─────────────────┘       └─────────────────┘

```

### Core Execution Mechanics

1. **The Proxy Core**: The proxy contract (`FactoryDiamond.sol` or `MarketplaceDiamond.sol`) maintains global state variables but contains no native application logic. It holds a mapping of four-byte function selectors to specific deployed Facet addresses.
2. **Delegatecall Routing**: When an external account or service invokes a function on the proxy address, the proxy's `fallback()` function intercepts the call, cross-references its internal selector map, and forwards the entire transaction execution environment to the target Facet via `delegatecall`.
3. **Isolated Storage**: Facets execute code within the execution context of the Diamond Proxy. State mutations persist exclusively inside the storage layout of the proxy contract, safeguarding data continuity across upgrades.

---

## 2. Directory Footprint Specification

Following the structural cleanup and migration, the `./smart-contracts` workspace contains exclusively source files, configuration manifests, and test configurations. All build output artifacts are isolated from version tracking:

```text
./smart-contracts
├── contracts/
│   ├── Diamond.sol
│   ├── facets/
│   │   ├── CreatorsFacet.sol
│   │   ├── DeployerFacet.sol
│   │   ├── DiamondCutFacet.sol
│   │   ├── DiamondLoupeFacet.sol
│   │   ├── ERC721EnumerableFacet.sol
│   │   ├── FeesFacet.sol
│   │   ├── MintingOffersFacet.sol
│   │   ├── OwnershipFacet.sol
│   │   ├── RAIRMetadataFacet.sol
│   │   ├── RAIRProductFacet.sol
│   │   ├── RAIRRangesFacet.sol
│   │   ├── RAIRRoyaltiesFacet.sol
│   │   ├── ResaleFacet.sol
│   │   └── TokensFacet.sol
│   ├── interfaces/
│   └── libraries/
├── scripts/
├── test/
├── hardhat.config.js
├── package.json
└── tsconfig.json

```

---

## 3. Detailed Facet Registry

The functional domain of the Diamond architecture is divided across specialized facets. Downstream indexers and clients target these components:

| Facet Identifier | Functional Mapping Domain | Crucial Structural Methods | Downstream Ingestion Dependency |
| --- | --- | --- | --- |
| `DiamondCutFacet` | Proxy configuration modification | `diamondCut()` | Administrative scripts during upgrades |
| `DiamondLoupe` | Selector and layout inspection | `facets()`, `facetAddress()` | Testing suites and web wallet discovery |
| `TokensFacet` | Core token lifecycle operations | `mint()`, `burn()`, `balanceOf()` | `event-worker` transaction validation |
| `RAIRProductFacet` | Access rules configuration | `createProduct()`, `setGatingRules()` | `core-api` access evaluation layer |
| `RAIRRangesFacet` | Token sequence batch segmentation | `setTokenRange()`, `getRangeData()` | Indexer inventory updates |
| `RAIRMetadataFacet` | IPFS URI and base pointer mapping | `setBaseURI()`, `tokenURI()` | Frontend client asset layout rendering |
| `RAIRRoyaltiesFacet` | EIP-2981 distribution protocols | `royaltyInfo()`, `setRoyalties()` | Marketplace processing nodes |
| `ERC721Enumerable` | Array enumeration and indexing | `tokenOfOwnerByIndex()` | Client user dashboard rendering |

---

## 4. Hardhat Compiler Optimization Specification

To guarantee that code packages successfully compile within acceptable EVM deployment bounds, the compiler configuration utilizes strict optimization constraints. The following configuration profile is established within `hardhat.config.js`:

```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
    localhost: {
      url: "[http://127.0.0.1:8545](http://127.0.0.1:8545)"
    }
  }
};

```

---

## 5. ABI Aggregation & Synchronization Pipeline

Because downstream components like `client` and `event-worker` interact with the Diamond Proxy as a single cohesive unit, they cannot consume isolated facet ABI files. An automated post-compilation aggregation sequence compiles these artifacts.

### The Combined ABI Generation Sequence

1. The compilation suite processes each contract inside `./smart-contracts/contracts/facets/`.
2. A build task reads the individual JSON files generated within the ephemeral local `artifacts/` cache.
3. The script extracts the `abi` array fields from each facet configuration, deduplicates overlapping standard functions, and flattens them into a single comprehensive array structure.
4. The aggregated object is written out to a shared file named `DiamondCombined.json`.

### Build Hook Sync Automation

An automated asset synchronization task handles the cross-directory copy operation directly to prevent structural desynchronization:

```bash
cp ./artifacts/DiamondCombined.json ../client/src/contracts/DiamondCombined.json
cp ./artifacts/DiamondCombined.json ../event-worker/src/abi/DiamondCombined.json

```

---

## 6. Local Node Integration & Orchestration Lifecycle

For development cycles, the local blockchain state runs inside the monorepo's shared virtualization cluster via `docker-compose.local-new.yml`. This decouples the development workspace from public testnets.

### Lifecycle Management Commands

To start the isolated development chain container:

```bash
docker-compose -f ../docker-compose.local-new.yml up -d chain

```

To view real-time transaction processing execution logs:

```bash
docker logs -f hardhat-node

```

### Script Execution Loop

When spinning up a new local development environment sandbox, operations are sequenced as follows:

```bash
npm install
npx hardhat compile
npx hardhat run scripts/deploy.js --network localhost

```

The initialization deployment scripts execute the following automated chain changes:

1. Deploy the fundamental proxy contracts (`FactoryDiamond`, `MarketplaceDiamond`).
2. Deploy each individual standalone application Facet contract.
3. Construct an array of `FacetCut` struct configurations containing the complete selector matrices.
4. Execute `diamondCut()` on the newly deployed proxy contracts to bind the logic paths.
5. Record the final functional proxy addresses into the shared local environment files for application discovery.