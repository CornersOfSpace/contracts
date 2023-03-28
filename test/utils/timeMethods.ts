import { BigNumber as BN } from "ethers";
import { ethers } from "hardhat";
const provider = ethers.provider;

export async function latest() {
  const block = await provider.getBlock("latest");
  return BN.from(block.number);
}

export async function advanceBlock(block: number) {
  const currentBlock = await provider.getBlock("latest");
  for (let i = 0; i < block; i++) {
    await provider.send("evm_mine", []);
  }
}
