import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { CornersOfSpace } from "../typechain-types/contracts/CornersOfSpace";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { TERC20 } from "../typechain-types/contracts/helpers/TERC20";

const args = "This is 20 symbols!!";
const getMessage = async (
  minter: string,
  free: boolean,
  price: BigNumber,
  payToken: string,
  nonce: number,
  sigDeadline: number | BigNumber,
  contract: string,
  referral?: string
) => {
  const typedData = {
    domain: {
      name: "Corners of Space",
      version: "1",
      chainId: 324,
      verifyingContract: contract.toLowerCase(),
    },
    types: {
      MessageType: [
        { name: "minter", type: "address" },
        { name: "free", type: "bool" },
        { name: "price", type: "uint256" },
        { name: "payToken", type: "address" },
        { name: "nonce", type: "uint256" },
        { name: "sigDeadline", type: "uint64" },
        { name: "args", type: "string" },
        { name: "referral", type: "address" },
      ],
    },
    message: {
      minter: minter,
      free: free,
      price: price,
      payToken: payToken,
      nonce: nonce,
      sigDeadline: sigDeadline,
      args: args,
      referral: referral ? referral : ethers.constants.AddressZero,
    },
  };
  // Sign the typed data object
  const Signer = new ethers.Wallet(process.env.DEPLOYER_PK as string);
  const signature = await Signer._signTypedData(
    typedData.domain,
    typedData.types,
    typedData.message
  );

  return signature;
};

const getBundleMessage = async (
  minter: string,
  free: boolean,
  price: BigNumber,
  payToken: string,
  nonce: number,
  amount: number,
  sigDeadline: number | BigNumber,
  contract: string,
  referral: string
) => {
  const typedData = {
    domain: {
      name: "Corners of Space",
      version: "1",
      chainId: 324,
      verifyingContract: contract.toLowerCase(),
    },
    types: {
      BundleType: [
        { name: "minter", type: "address" },
        { name: "free", type: "bool" },
        { name: "price", type: "uint256" },
        { name: "payToken", type: "address" },
        { name: "nonce", type: "uint256" },
        { name: "sigDeadline", type: "uint64" },
        { name: "args", type: "string" },
        { name: "amount", type: "uint256" },
        { name: "referral", type: "address" },
      ],
    },
    message: {
      minter: minter,
      free: free,
      price: price,
      payToken: payToken,
      nonce: nonce,
      sigDeadline: sigDeadline,
      args: args,
      amount: amount,
      referral: referral,
    },
  };

  // Sign the typed data object
  const Signer = new ethers.Wallet(process.env.DEPLOYER_PK as string);
  const signature = await Signer._signTypedData(
    typedData.domain,
    typedData.types,
    typedData.message
  );

  return signature;
};

async function main() {
  // Create deployer object and load the artifact of the contract you want to deploy.

  const cos = (await ethers.getContractAt(
    "CornersOfSpace",
    "0x85c6C7B1E4dea91954CebA1CFA56066C60afAa1F".toLowerCase()
  )) as CornersOfSpace;
  const token = (await ethers.getContractAt(
    "TERC20",
    "0xF4A1811D267Bc75Fd38247c9DCF3bad6DE169707"
  )) as TERC20;
  //await token.approve(cos.address, ethers.utils.parseEther("100"));
  console.log(
    await getMessage(
      "0x9f322A100bA797835AF291edCC4603D3D2e7913e".toLowerCase(),
      true,
      ethers.utils.parseEther("1"),
      token.address,
      2,
      1993399,
      cos.address
    )
  );
  console.log("Minting...");
  const nonce1 = 105;
  await (
    await cos.mint(
      true,
      token.address,
      ethers.utils.parseEther("1"),
      nonce1,
      1993399,
      await getMessage(
        "0x9f322A100bA797835AF291edCC4603D3D2e7913e".toLowerCase(),
        true,
        ethers.utils.parseEther("1"),
        token.address,
        nonce1,
        1993399,
        cos.address
      ),
      args,
      ethers.constants.AddressZero
    )
  ).wait();
  const block = 2993399;
  const nonce = 11;
  await (
    await cos.bundleMint(
      false,
      token.address,
      ethers.utils.parseEther("1"),
      nonce,
      block,
      getBundleMessage(
        "0x9f322A100bA797835AF291edCC4603D3D2e7913e".toLowerCase(),
        false,
        ethers.utils.parseEther("1"),
        token.address,
        nonce,
        10,
        block,
        cos.address,
        ethers.constants.AddressZero
      ),
      args,
      10,
      ethers.constants.AddressZero
    )
  ).wait();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
