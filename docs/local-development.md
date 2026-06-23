# Local Development & Environment Configuration

This document outlines the steps required to configure, spin up, and run the platform microservices locally using your terminal or the refactored Docker Compose database setup.

---

## 1. Prerequisite Infrastructure

The `client`, `core-api`, `media-transcoder`, and `event-worker` services require instances of MongoDB and Redis to function. You can run these natively on your machine or utilize the optimized database blocks in `docker-compose.local-new.yml`:

```bash
# Spin up only the background databases in detached mode
docker-compose -f docker-compose.local-new.yml up -d mongo redis

```

---

## 2. Global Environment Variables (`.env`)

You must create individual `.env` configuration files inside the root directory of your target microservices. Use the definitions below to assemble your configurations.

### 2.1 Core API & Worker Shared Credentials

Create a `.env` profile for the core backend microservices (`core-api` and `event-worker`).

| Key Name | Suggested Local Value | Purpose / Origin |
| --- | --- | --- |
| `LOCAL_DB_USER` | `admin` | Root username for your local MongoDB container |
| `LOCAL_DB_PASS` | `password123` | Root password for your local MongoDB container |
| `MONGO_DB_NAME` | `sandbox-db` | Target collection namespace inside Mongo |
| `JWT_SECRET` | `generate_a_random_string` | Secret hash used to sign user auth tokens |
| `SESSION_SECRET` | `generate_another_string` | Express session encryption passphrase |
| `SESSION_TTL` | `86400` | Redis user session time-to-live in seconds |
| `LOG_LEVEL` | `debug` | Verbosity of stdout service tracking logs |

### 2.2 Blockchain & External API Integrations

These variables bind your localized worker loops to real-time blockchain telemetry structures.

| Key Name | Target Configuration | Purpose |
| --- | --- | --- |
| `ALCHEMY_API_KEY` | `your_alchemy_key_here` | Personal Web3 RPC access gateway key |
| `ADMIN_NFT_CHAIN` | `amoy` / `polygon` | Target EVM blockchain network identifier |
| `ADMIN_CONTRACT` | `0x...` | Main factory smart contract tracking target |
| `WITHDRAWER_PRIVATE_KEY` | `0x...` | Optional wallet private key for gas relay operations |
| `PINATA_KEY` | `your_pinata_key` | IPFS pinning gateway credential |
| `PINATA_SECRET` | `your_pinata_secret` | IPFS pinning gateway signature layer |
| `PINATA_GATEWAY` | `https://gateway.pinata.cloud` | Public fallback storage download proxy location |

### 2.3 Client (Frontend) Profile

Create a `.env` file inside the `./client` subdirectory. Because this app is compiled via Vite, variables **must** be prefixed with `VITE_` to be exposed to your frontend bundle.

```text
VITE_HOME_PAGE=/
VITE_NODE_SOCKET_URI=http://localhost:5000
VITE_MATIC_MAIN_DIAMOND_FACTORY=0x...
VITE_MATIC_MAIN_DIAMOND_MARKETPLACE=0x...

```

---

## 3. Running Services Natively (Without Heavy Containers)

Running microservices natively in separate terminal windows gives you instant hot-reloading and clear stack traces.

### 3.1 Booting the Core API Backend

```bash
cd core-api
npm install
npm run dev   # Or node bin/index.js depending on your package scripts

```

The API engine will initialize and mount a listener loop on `http://localhost:5000`.

### 3.2 Booting the Blockchain Indexer Loop

```bash
cd event-worker
npm install
npm run start

```

The event scheduler worker will establish connectivity with your Redis cache, pair with your custom Alchemy RPC endpoint, and wait for event signatures.

### 3.3 Booting the Web Client

```bash
cd client
yarn install
yarn dev

```

The Vite bundler will spin up a highly responsive development environment, typically mounted at `http://localhost:5173` or port mapped to your custom parameters.

---

## 4. Operational Diagnostics Checklist

Before running tests, verify database health parameters:

1. Ensure your local MongoDB image is processing commands by running `docker logs mongo`.
2. Verify Redis availability by connecting via CLI: `docker exec -it redis redis-cli ping` (Should return `PONG`).
3. Assert that your client bundle is directing backend fetch targets straight to your localized `core-api` port mapping (`5000`) rather than old staging cluster locations.