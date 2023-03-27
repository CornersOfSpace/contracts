import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "hardhat-deploy";

const packageJson = require("./package.json");

const accounts =
  process.env.PRIVATE_KEY !== undefined
    ? [process.env.PRIVATE_KEY as string]
    : [];

const config: HardhatUserConfig = {
  solidity: "0.8.17",

  networks: {
    bsc: {
      url: `${process.env.BSC_RPC_URL}`,
      accounts: accounts,
    },
    bscTestnet: {
      url: `https://rpc.ankr.com/bsc_testnet_chapel`,
      accounts: accounts,
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
  },

  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  paths: {
    deployments: `deployments/${packageJson.version}`,
  },
};

export default config;
