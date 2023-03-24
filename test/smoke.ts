import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { CornersOfSpace, TERC20 } from "../typechain-types";

// import { advanceBlockTo, advanceTimeAndBlock } from "./utils/timeMethods";

const getMessage = async (
  signer: SignerWithAddress,
  free: boolean,
  nonce: number,
  nft: string,
  args: string
) => {
  const message = ethers.utils.keccak256(
    ethers.utils.solidityPack(
      ["bool", "uint256", "address", "string"],
      [free, nonce, nft, args]
    )
  );

  const signedMessage = await signer.signMessage(
    ethers.utils.arrayify(message)
  );
  return signedMessage;
};

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
      nft = await (
        await ethers.getContractFactory("CornersOfSpace")
      ).deploy(
        deployer.address,
        ultimateAdmin.address,
        deployer.address,
        "Corners of Space",
        "CoS",
        "uri"
      );
      paymentToken = await (
        await ethers.getContractFactory("TERC20")
      ).deploy("TERC20", "TERC20", 100);
    });

    it("should let mint tokens correctly", async () => {
      await nft
        .connect(user)
        .mint(
          true,
          paymentToken.address,
          "",
          nonce,
          await getMessage(deployer, true, nonce, nft.address, "")
        );
      nonce++;

      expect(await nft.ownerOf(1)).to.equal(user.address);
    });
    it("should not let user mint more tokens then a limit", async () => {
      await nft
        .connect(user)
        .bundleMint(
          true,
          paymentToken.address,
          "",
          nonce,
          await getMessage(deployer, true, nonce, nft.address, ""),
          9
        );
      nonce++;

      expect(await nft.ownerOf(1)).to.equal(user.address);
    });
  });
});
