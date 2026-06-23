# System Architecture Specification

This document provides a functional blueprint of the decoupled, 4-tier microservices architecture powering this platform. The system is engineered to handle Web3 state tracking, cryptographic authentication, and token-gated digital rights management (DRM) for multimedia asset delivery.

---

## 1. Component Overview

The codebase is partitioned into four distinct operational containers communicating over an isolated virtual bridge network, backed by persistent data layers.

```text
                  ┌────────────┐
                  │   client   │ (React + Vite Frontend)
                  └─────┬──────┘
                        │
         ┌──────────────┴──────────────┐
         ▼                             ▼
   ┌───────────┐                 ┌──────────────┐
   │ core-api  │ ◄─────────────► │ event-worker │
   └─────┬─────┘                 └──────┬───────┘
         │                              │
         ▼                              ▼
   ┌──────────────┐              ┌──────────────┐
   │  media-      │              │ Alchemy / EVM│
   │  transcoder  │              │ Blockchain   │
   └──────────────┘              └──────────────┘

```

### Core Services

* **`client`**: A high-performance single-page application built on React, TypeScript, and Vite. It serves the interface, handles user wallet connectivity, captures cryptographic signatures for authentication, and embeds the customized video player.
* **`core-api`**: The central application hub powered by Node.js and Express. It manages persistent business logic via MongoDB, coordinates session handling with Redis, validates user wallet signatures, and enforces permission gates before unlocking secure media metadata.
* **`media-transcoder`**: A microservice dedicated to asset security. It intercepts raw media uploads and leverages Fluent-FFmpeg to slice and transcode files into encrypted HTTP Live Streaming (`.m3u8` / HLS) video fragments, binding stream decryption to contract authorization hooks.
* **`event-worker`**: An event-driven background listener. Using the Agenda framework, it maintains an active RPC sync interface with the EVM blockchain through the Alchemy SDK. It aggregates contract transfer/mint events to natively maintain the synchronization state of the local database without relying on third-party indexers.

---

## 2. Infrastructure & Network Topology

All components interact over a localized Docker network driver using specific internal port configurations:

| Service Name | External Port | Internal Port | Primary Dependency | Purpose |
| --- | --- | --- | --- | --- |
| `client` | `8088` | `80` | `core-api` | Serves production-built frontend |
| `core-api` | `5000` | `5000` | `mongo`, `redis` | Main REST API & WebSockets hub |
| `event-worker` | `5001` | `5001` | `core-api`, `mongo` | Local indexer & cron loop runner |
| `media-transcoder` | `5002` | `5002` | `redis` | Decoupled audio/video processing engine |
| `mongo` | `27017` | `27017` | None | Primary application database storage |
| `redis` | `6379` | `6379` | None | Active user sessions & caching |

---

## 3. Primary Data Cycles & Workflows

### 3.1 Cryptographic Authentication Loop

1. The **`client`** requests a randomized challenge string from the **`core-api`** via `/api/auth/challenge`.
2. The user signs this unique challenge string locally inside their Web3 wallet provider (e.g., MetaMask).
3. The resulting cryptographic signature is transmitted to the server via `/api/auth/verify`.
4. The **`core-api`** uses `ethers.js` utility tools to safely reverse-recover the public wallet address from the signature. If validated, it instantiates an active session cache inside **`redis`**.

### 3.2 Secure Media Encrypted Streaming Pipeline

1. An asset creator uploads raw video data through the administrative dashboard.
2. The **`media-transcoder`** grabs the file, splits the video into standardized `.ts` chunks, and attaches an AES-128 encryption wrapper key.
3. Transcoded chunks are pushed out to distributed storage environments (IPFS/Pinata), while the access logic is synchronized back into **`core-api`**.
4. When a user requests playback, the client submits a wallet validation ticket. The **`core-api`** asserts the token balance against the MongoDB state:
* **Pass:** The server safely delivers the decryption manifest file directly into the media player wrapper.
* **Fail:** The system returns an explicit `403 Unauthorized` payload, isolating the protected asset chunks from un-entitled consumption.



### 3.3 Blockchain Synchronization Loop

1. The **`event-worker`** boots up an infinite loop mapped across target block-ranges using dedicated RPC endpoints.
2. When a factory tracking system catches a new contract deployment, a mint transaction, or a marketplace transfer event, a secondary parse mapping captures the transaction receipt metadata.
3. The parameters are filtered, mapped, and synchronized straight into the **`mongo`** collection layer, allowing the **`core-api`** to return near-real-time global ecosystem inventory status metrics without making high-latency blocking web requests directly to the blockchain on every single page load.

---

## 4. Development Guides & Local Execution

Documentation regarding individual component execution scripts, environment settings profiles, and dependency update structures are separated within relative folders:

* See [API Specification Reference](https://www.google.com/search?q=./api-endpoints.md) to review endpoint schemas and response shapes.