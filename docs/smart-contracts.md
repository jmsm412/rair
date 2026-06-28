# Smart Contract Subsystem Architecture & Lifecycle Specification

This specification covers the implementation, structure, and operational lifecycle of the EIP-2535 Diamond Standard smart contracts within the `./smart-contracts` workspace of the monorepo. This subsystem handles tokenization, media access management, and asset gating configurations, fully upgraded to Hardhat 3, ECMAScript Modules (ESM), and containerized testing standards.

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

1. **The Proxy Core**: The proxy contracts (`FactoryDiamond.sol` and `MarketplaceDiamond.sol`) maintain global state variables but contain no native application logic. They hold a mapping of four-byte function selectors to specific deployed Facet addresses.
2. **Delegatecall Routing**: When an external account or service invokes a function on a proxy address, the proxy's `fallback()` function intercepts the call, cross-references its internal selector map, and forwards the entire transaction execution environment to the target Facet via `delegatecall` using the high-performance EDR runtime.
3. **Isolated Storage**: Facets execute code within the execution context of the Diamond Proxy. State mutations persist exclusively inside the storage layout of the proxy contract, safeguarding data continuity across upgrades.

---

## 2. Directory Footprint Specification

Following the structural cleanup, dependency pruning, and ESM migration, the `./smart-contracts` workspace isolates all operational assets into two explicit execution zones:

```text
./smart-contracts
├── contracts/
│   ├── Diamond.sol
│   ├── Factory/
│   │   ├── FactoryDiamond.sol
│   │   └── facets/
│   ├── Marketplace/
│   │   ├── MarketplaceDiamond.sol
│   │   └── facets/
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
├── deploy/
│   └── 01_deploy_all.js
├── scripts/
│   ├── utils/
│   │   └── deployAndVerify.js
│   └── aggregateAbis.js
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
| `DiamondLoupeFacet` | Selector and layout inspection | `facets()`, `facetAddress()` | Testing suites and web wallet discovery |
| `TokensFacet` | Core token lifecycle operations | `mint()`, `burn()`, `balanceOf()` | `event-worker` transaction validation |
| `RAIRProductFacet` | Access rules configuration | `createProduct()`, `setGatingRules()` | `core-api` access evaluation layer |
| `RAIRRangesFacet` | Token sequence batch segmentation | `setTokenRange()`, `getRangeData()` | Indexer inventory updates |
| `RAIRMetadataFacet` | IPFS URI and base pointer mapping | `setBaseURI()`, `tokenURI()` | Frontend client asset layout rendering |
| `RAIRRoyaltiesFacet` | EIP-2981 distribution protocols | `royaltyInfo()`, `setRoyalties()` | Marketplace processing nodes |
| `ERC721EnumerableFacet` | Array enumeration and indexing | `tokenOfOwnerByIndex()` | Client user dashboard rendering |

---

## 4. Hardhat Compiler & Network Specification (SC-03)

To ensure that code packages successfully compile within acceptable EVM deployment bounds, the compiler configuration utilizes strict optimization constraints running under a native ES Module format (`"type": "module"`).

### 4.1 Sizing Boundary Protections

The system targets dual-compiler profiles to manage both standard application files and diamond structural interfaces under a uniform optimization boundary:

* **Solidity v0.8.25 & v0.8.19**
* **Optimizer Status:** Enabled
* **Optimizer Runs:** 200

### 4.2 Lazy-Loading Environment Validation

Hardhat 3 enforces strict, synchronous URL pattern validation at startup. To prevent configuration crashes during local compilation tasks when environment keys are absent, network variables utilize the `configVariable` lazy-loading entry hook.

```javascript
import "dotenv/config";
import { defineConfig, configVariable } from "hardhat/config";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatDeploy from "hardhat-deploy";
import hardhatContractSizer from "@solidstate/hardhat-contract-sizer";

export default defineConfig({
    plugins: [
        hardhatToolboxMochaEthers,
        hardhatDeploy,
        hardhatContractSizer
    ],
    networks: {
        hardhat: {
            type: "edr-simulated",
            forking: {
                url: configVariable("ETH_MAIN_RPC"),
                blockNumber: 22221970,
            }
        },
        "localhost": {
            type: "http",
            url: configVariable("LOCALHOST_RPC_URL"),
            accounts: [configVariable("ADDRESS_PRIVATE_KEY")]
        }
    },
    solidity: {
        compilers: [
            {
                version: "0.8.25",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            },
            {
                version: "0.8.19",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200
                    }
                }
            }
        ],
    },
    contractSizer: {
        runOnCompile: true,
        strict: true
    }
});

```

---

## 5. Live Delta-Upgrade & Deployment Scripting (SC-04)

Deployments are managed by a centralized orchestration runner file (`./smart-contracts/deploy/01_deploy_all.js`).

### 5.1 Step Extraction Toggles

The execution path is managed by a centralized `DEPLOY_FLAGS` configuration object. Modifying these boolean attributes isolates specific contract classes without modifying the master deployment sequence code:

```javascript
const DEPLOY_FLAGS = {
    facets: true,
    erc20: false,
    erc20Exchange: false,
    diamondFactory: true,
    diamondMarketplace: true,
    facetSource: false
};

```

### 5.2 Automated On-Chain Differential Processing

To support modular upgrades, the script performs a live selector delta analysis when targeting an active Diamond Proxy:

1. It reads local compiled facet code structures and extracts function selectors using Ethers v6 reflection.
2. It calls `facets()` on the deployed `DiamondLoupeFacet` proxy address to build a map of on-chain selector locations.
3. It performs a state diff comparison to determine the necessary mutations:
* **`FacetCutAction.Add (0)`**: Automatically allocated for entirely new method selectors.
* **`FacetCutAction.Replace (1)`**: Automatically allocated if an existing function selector points to a newly updated facet address.


4. The calculated updates are bundled and submitted in a single `diamondCut` call, executing atomic facet hot-swaps on the active proxy.

---

## 6. ABI Aggregation & Synchronization Pipeline (SC-05 / SC-06)

Because downstream components like `client` and `event-worker` interact with the Diamond Proxy as a single cohesive unit, they cannot consume isolated facet ABI files. An automated post-compilation aggregation sequence compiles these artifacts.

```text
  [Hardhat Compilation] ──► Individual Facet JSON Artifacts
                                     │
                                     ▼
                        [scripts/aggregateAbis.js]
                                     │
                ┌────────────────────┴────────────────────┐
                ▼                                         ▼
    [Deduplicate Selectors]                     [Multi-Service Dispatch]
                │                                         │
                ▼                                         ▼
       DiamondCombined.json ──────────────┬───────────────┤
                                          ▼               ▼
                                       client/      event-worker/

```

### 6.1 Deduplication Loop

The aggregation utility recursively processes files inside `./artifacts/contracts/`, filtering out structural debugging logs. It reads individual facet ABI arrays, evaluates function names alongside their input types, deduplicates overlapping signatures, and outputs a unified schema file: **`DiamondCombined.json`**.

### 6.2 Multi-Service Asset Dispatcher

To prevent asset desynchronization across the monorepo, the script uses path-safe node routines to distribute copies of the generated artifact straight to dependent microservices:

* **`client` Path:** `../client/src/abis/DiamondCombined.json`
* **`event-worker` Path:** `../event-worker/src/abis/DiamondCombined.json`

---

## 7. Local Node Provisioning & Infrastructure Lifecycle (SC-07)

For development cycles, the local blockchain state runs inside the monorepo's shared virtualization cluster via `docker-compose.local-new.yml`. This decouples the development workspace from public testnets.

### 7.1 Container Engine Specifications

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

### 7.2 Command Reference Manual

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

#### Connect Microservices to Containerized Node

To connect your backend application services, point your root environment variables to the container's internal bridge hostname:

```env
ALCHEMY_API_KEY=http://evm-node:8545

```