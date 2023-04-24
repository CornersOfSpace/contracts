import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-ethers";
import "solidity-coverage";
import "hardhat-abi-exporter";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-deploy";
import "@matterlabs/hardhat-zksync-solc";
import "@matterlabs/hardhat-zksync-verify";

dotenv.config();

const packageJson = require("./package.json");

const accounts =
  process.env.DEPLOYER_PK !== undefined
    ? [process.env.DEPLOYER_PK as string]
    : [];

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },
  zksolc: {
    version: "1.3.8",
    compilerSource: "binary",
    settings: {},
  },
  //defaultNetwork: "zkSyncTestnet",

  networks: {
    bscMainnet: {
      url: `${process.env.BSC_MAINNET_RPC}`,
      accounts: accounts,
    },
    bscTestnet: {
      url: `${process.env.BSC_TESTNET_RPC}`,
      accounts: accounts,
    },
    goerli: {
      url: "https://rpc.ankr.com/eth_goerli", // The Ethereum Web3 RPC URL (optional).
    },
    zkSyncTestnet: {
      url: "https://testnet.era.zksync.dev",
      ethNetwork: "goerli", // RPC URL of the network (e.g. `https://goerli.infura.io/v3/<API_KEY>`)
      accounts: accounts,
      zksync: true,
      verifyURL:
        "https://zksync2-testnet-explorer.zksync.dev/contract_verification",
    },
    zkSync: {
      url: "https://mainnet.era.zksync.io",
      ethNetwork: "https://rpc.ankr.com/eth",
      accounts: accounts,
      zksync: true,
      verifyURL:
        "https://zksync2-mainnet-explorer.zksync.io/contract_verification",
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    coinmarketcap: `${process.env.COINMARKETCAP_API}`,
    token: "ETH",
    gasPriceApi: "https://api.bscscan.com/api?module=proxy&action=eth_gasPrice",
  },

  abiExporter: {
    path: "./dist",
    runOnCompile: true,
    clear: true,
    flat: true,
    pretty: false,
  },

  etherscan: {
    apiKey: process.env.BSCSCAN_API_KEY,
  },

  paths: {
    deployments: `deployments/${packageJson.version}`,
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};

export default config;
