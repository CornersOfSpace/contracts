import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { CornersOfSpace, TERC20 } from "../typechain-types";

// import { advanceBlockTo, advanceTimeAndBlock } from "./utils/timeMethods";

const args = "This is 20 symbols!!";
const getMessage = async (
  signer: SignerWithAddress,
  free: boolean,
  price: BigNumber,
  nonce: number
) => {
  const message = ethers.utils.keccak256(
    ethers.utils.solidityPack(
      ["bool", "uint256", "uint256", "string"],
      [free, price, nonce, args]
    )
  );

  const signedMessage = await signer.signMessage(
    ethers.utils.arrayify(message)
  );
  return signedMessage;
};

const getBundleMessage = async (
  signer: SignerWithAddress,
  free: boolean,
  price: BigNumber,
  nonce: number,
  amount: number
) => {
  const message = ethers.utils.keccak256(
    ethers.utils.solidityPack(
      ["bool", "uint256", "uint256", "string", "uint256"],
      [free, price, nonce, args, amount]
    )
  );

  const signedMessage = await signer.signMessage(
    ethers.utils.arrayify(message)
  );
  return signedMessage;
};
const price = ethers.utils.parseEther("1");

describe("Smoke functionality of Corners of Space NFT minting", () => {
  context("Smoke tests", async () => {
    let deployer: SignerWithAddress,
      hacker: SignerWithAddress,
      user: SignerWithAddress,
      ultimateAdmin: SignerWithAddress;
    let paymentToken: TERC20;
    let nft: CornersOfSpace;
    let nonce = 0;

    before(async () => {
      [deployer, hacker, user, ultimateAdmin] = await ethers.getSigners();
      nft = (await (
        await ethers.getContractFactory("CornersOfSpace")
      ).deploy(
        deployer.address,
        ultimateAdmin.address,
        deployer.address,
        ethers.constants.AddressZero,
        price,
        "Corners of Space",
        "CoS",
        "uri"
      )) as CornersOfSpace;
      paymentToken = await (
        await ethers.getContractFactory("TERC20")
      ).deploy("TERC20", "TERC20", 100);
    }) as TERC20;

    it("should let mint tokens correctly", async () => {
      await nft
        .connect(user)
        .mint(
          true,
          paymentToken.address,
          price,
          nonce,
          await getMessage(deployer, true, price, nonce),
          args
        );
      nonce++;

      expect(await nft.ownerOf(1)).to.equal(user.address);
    });
    it("should not let user mint more tokens then a limit", async () => {
      const amountToMint = 9;
      await nft
        .connect(user)
        .bundleMint(
          true,
          paymentToken.address,
          price,
          nonce,
          await getBundleMessage(deployer, true, price, nonce, amountToMint),
          args,
          amountToMint
        );
      nonce++;

      expect(await nft.ownerOf(1)).to.equal(user.address);
    });
  });
});
