import "dotenv/config";
import { defineConfig, configVariable } from "hardhat/config";
import hardhatToolboxMochaEthers from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatDeploy from "hardhat-deploy";
import hardhatContractSizer from "@solidstate/hardhat-contract-sizer";

const {
    COINMARKETCAP_API_KEY,
    ETHERSCAN_API_KEY,
    POLYGONSCAN_API_KEY,
    OKLINK_API_KEY,
    BASESCAN_API_KEY,
    BLOCKSCOUT_API_KEY,
    CORESCAN_API_KEY,
} = process.env;

const commonConfig = {
    accounts: [configVariable("ADDRESS_PRIVATE_KEY")]
};

export default defineConfig({
    plugins: [
        hardhatToolboxMochaEthers,
        hardhatDeploy,
        hardhatContractSizer
    ],
    networks: {
        "localhost": {
            type: "http",
            url: "http://127.0.0.1:8545",
            ...commonConfig,
        },
        hardhat: {
            type: "edr-simulated",
            forking: {
                url: configVariable("ETH_MAIN_RPC"),
                blockNumber: 22221970,
            }
        },
        "0x1": {
            type: "http",
            url: configVariable("ETH_MAIN_RPC"),
            ...commonConfig,
        },
        "0x89": {
            type: "http",
            url: configVariable("MATIC_RPC"),
            ...commonConfig,
        },
        "0x250": {
            type: "http",
            url: configVariable("ASTAR_RPC"),
            ...commonConfig,
        },
        "0xaa36a7": {
            type: "http",
            url: configVariable("SEPOLIA_RPC"),
            ...commonConfig,
        },
        "0x13882": {
            type: "http",
            url: configVariable("AMOY_RPC"),
            ...commonConfig,
        },
        "0x2105": {
            type: "http",
            url: configVariable("BASE_RPC"),
            ...commonConfig,
        },
        "0x45c": {
            type: "http",
            url: configVariable("CORE_RPC"),
            ...commonConfig,
        },
        "0x79a": {
            type: "http",
            url: configVariable("MINATO_RPC"),
            ...commonConfig,
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
    },
    sourcify: {
        enabled: false,
    },
    mocha: {
        timeout: 0
    },
    gasReporter: {
        currency: 'USD',
        showTimeSpent: true,
        coinmarketcap: COINMARKETCAP_API_KEY || undefined,
        L1Etherscan: ETHERSCAN_API_KEY || undefined,
    },
    etherscan: {
        apiKey: {
            mainnet: ETHERSCAN_API_KEY,
            sepolia: ETHERSCAN_API_KEY,
            polygon: POLYGONSCAN_API_KEY,
            polygonAmoy: OKLINK_API_KEY,
            base: BASESCAN_API_KEY,
            astar: BLOCKSCOUT_API_KEY,
            core: CORESCAN_API_KEY,
            minato: '???'
        },
        customChains: [
            {
                network: "astar",
                chainId: 592,
                urls: {
                    apiURL: "https://astar.blockscout.com/api/",
                    browserURL: "https://astar.blockscout.com/"
                }
            },
            {
                network: "core",
                chainId: 1116,
                urls: {
                    apiURL: "https://openapi.coredao.org/api",
                    browserURL: "https://scan.coredao.org/"
                }
            },
            {
                network: "minato",
                chainId: 1946,
                urls: {
                    apiURL: "https://explorer-testnet.soneium.org/api/",
                    browserURL: "https://explorer-testnet.soneium.org/"
                }
            },
        ],
    }
});