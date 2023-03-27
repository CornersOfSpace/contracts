import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";

// import { advanceBlockTo, advanceTimeAndBlock } from "./utils/timeMethods";

const args = "This is 20 symbols!!";
const getMessage = async (
  signer: SignerWithAddress,
  minter: SignerWithAddress,
  free: boolean,
  price: BigNumber,
  nonce: number
) => {
  const message = ethers.utils.keccak256(
    ethers.utils.solidityPack(
      ["address", "bool", "uint256", "uint256", "uint64", "string"],
      [minter.address, free, price, nonce, 1000000, args]
    )
  );

  const signedMessage = await signer.signMessage(
    ethers.utils.arrayify(message)
  );
  return signedMessage;
};

const getBundleMessage = async (
  signer: SignerWithAddress,
  minter: SignerWithAddress,
  free: boolean,
  price: BigNumber,
  nonce: number,
  amount: number
) => {
  const message = ethers.utils.keccak256(
    ethers.utils.solidityPack(
      ["address", "bool", "uint256", "uint256", "uint64", "string", "uint256"],
      [minter.address, free, price, nonce, 1000000, args, amount]
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
        "Corners of Space",
        "CoS",
        "uri"
      )) as unknown as CornersOfSpace;
      paymentToken = await (
        await ethers.getContractFactory("TERC20")
      ).deploy("TERC20", "TERC20", 100);
    }) as unknown as TERC20;

    it("should let mint tokens correctly", async () => {
      await nft
        .connect(user)
        .mint(
          true,
          paymentToken.address,
          price,
          nonce,
          "1000000",
          await getMessage(deployer, user, true, price, nonce),
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
          "1000000",
          await getBundleMessage(
            deployer,
            user,
            true,
            price,
            nonce,
            amountToMint
          ),
          args,
          amountToMint
        );
      nonce++;

      expect(await nft.ownerOf(1)).to.equal(user.address);
    });
  });
});
