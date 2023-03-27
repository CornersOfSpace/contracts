import * as dotenv from "dotenv";

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-ethers";
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
  solidity: "0.8.17",

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
