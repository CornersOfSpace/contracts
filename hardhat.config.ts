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

dotenv.config();

const packageJson = require("./package.json");

const accounts =
  process.env.DEPLOYER_PK !== undefined
    ? [process.env.DEPLOYER_PK as string]
    : [];

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: { optimizer: { enabled: true, runs: 200 } },
  },

  networks: {
    bscMainnet: {
      url: `${process.env.BSC_MAINNET_RPC}`,
      accounts: accounts,
    },
    bscTestnet: {
      url: `${process.env.BSC_TESTNET_RPC}`,
      accounts: accounts,
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    coinmarketcap: `${process.env.COINMARKETCAP_API}`,
    token: "BNB",
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
