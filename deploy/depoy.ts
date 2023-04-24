import { Wallet, utils } from "zksync-web3";
import * as ethers from "ethers";
import { ethers as a } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import * as dotenv from "dotenv";
dotenv.config();

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the Greeter contract`);

  // Initialize the wallet.
  const wallet = new Wallet(process.env.DEPLOYER_PK as string);

  // Create deployer object and load the artifact of the contract you want to deploy.
  const deployer = new Deployer(hre, wallet);
  const artifact = await deployer.loadArtifact("CornersOfSpace");
  const artifact2 = await deployer.loadArtifact("TERC20");

  // Estimate contract deployment fee
  const greeting = "Hi there!";
  const deploymentFee = await deployer.estimateDeployFee(artifact, [
    process.env.ADMIN_ADDRESS,
    process.env.ULTIMATE_ADMIN_ADDRESS,
    process.env.VERIFIER_ADDRESS,
    process.env.PRICE_FEED,
    process.env.NFT_NAME,
    process.env.NFT_SYMBOL,
    process.env.BASE_URI,
  ]);

  const deploymentFee2 = await deployer.estimateDeployFee(artifact2, [
    "name",
    "symbol",
    100,
  ]);

  //   // OPTIONAL: Deposit funds to L2
  //   // Comment this block if you already have funds on zkSync.
  //   console.log("Depositing funds to L2");
  //   const depositHandle = await deployer.zkWallet.deposit({
  //     to: deployer.zkWallet.address,
  //     token: utils.ETH_ADDRESS,
  //     amount: deploymentFee.add(deploymentFee2).add(deploymentFee2),
  //   });
  //   // Wait until the deposit is processed on zkSync
  //   await depositHandle.wait();

  // Deploy this contract. The returned object will be of a `Contract` type, similarly to ones in `ethers`.
  // `greeting` is an argument for contract constructor.
  const parsedFee = ethers.utils.formatEther(deploymentFee.toString());
  const parseFee2 = ethers.utils.formatEther(deploymentFee2.toString());
  console.log(`The deployment is estimated to cost ${parsedFee} ETH`);

  const greeterContract = await deployer.deploy(artifact, [
    process.env.ADMIN_ADDRESS,
    process.env.ULTIMATE_ADMIN_ADDRESS,
    process.env.VERIFIER_ADDRESS,
    process.env.PRICE_FEED,
    process.env.NFT_NAME,
    process.env.NFT_SYMBOL,
    process.env.BASE_URI,
  ]);
  const TERC20contract = await deployer.deploy(artifact2, [
    "name",
    "symbol",
    100,
  ]);

  //obtain the Constructor Arguments
  console.log(
    "constructor args:" +
      greeterContract.interface.encodeDeploy([
        process.env.ADMIN_ADDRESS,
        process.env.ULTIMATE_ADMIN_ADDRESS,
        process.env.VERIFIER_ADDRESS,
        process.env.PRICE_FEED,
        process.env.NFT_NAME,
        process.env.NFT_SYMBOL,
        process.env.BASE_URI,
      ])
  );

  // Show the contract info.
  const contractAddress = greeterContract.address;
  console.log(`${artifact.contractName} was deployed to ${contractAddress}`);
  console.log("terc20 :", TERC20contract.address);
}
