import { ethers } from "hardhat";
import { CornersOfSpace } from "../typechain-types/contracts/CornersOfSpace";

async function main() {
  // Create deployer object and load the artifact of the contract you want to deploy.

  const cos = (await ethers.getContractAt(
    "CornersOfSpace",
    "0x85c6C7B1E4dea91954CebA1CFA56066C60afAa1F"
  )) as CornersOfSpace;

  console.log("Setting Shares...");
  await cos.setShare(
    process.env.LIQUIDITY_SHARE as string,
    process.env.DAO_SHARE as string
  );

  console.log("Setting Receivers...");
  await cos.setReceivers(
    process.env.DAO as string,
    process.env.LIQUIDITY_RECEIVER as string
  );

  console.log("Setting PayTokens...");
  await cos.setReceivers(
    process.env.DAO as string,
    process.env.LIQUIDITY_RECEIVER as string
  );

  console.log("Setting sell token1...");

  await cos.setPayTokenStatus(
    "0xF4A1811D267Bc75Fd38247c9DCF3bad6DE169707",
    true
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
