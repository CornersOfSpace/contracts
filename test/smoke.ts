import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { CornersOfSpace } from "../typechain-types/contracts/CornersOfSpace";
import { TERC20 } from "../typechain-types/contracts/helpers/TERC20";
import { MockChainlink } from "../typechain-types/contracts/helpers/MockChainlink";

import { advanceBlock, latest } from "./utils/timeMethods";

const args = "This is 20 symbols!!";
const sigValidity = 100;
const getSigDeadline = async () => (await latest()).add(sigValidity);
const liquidityShare = 95;
const daoShare = 5;

const getMessage = async (
  signer: SignerWithAddress,
  minter: SignerWithAddress,
  free: boolean,
  price: BigNumber,
  payToken: string,
  nonce: number,
  sigDeadline: number | BigNumber,
  referral?: string
) => {
  const message = ethers.utils.keccak256(
    ethers.utils.solidityPack(
      [
        "address",
        "bool",
        "uint256",
        "address",
        "uint256",
        "uint64",
        "string",
        "address",
      ],
      [
        minter.address,
        free,
        price,
        payToken,
        nonce,
        sigDeadline,
        args,
        referral ? referral : ethers.constants.AddressZero,
      ]
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
  payToken: string,
  nonce: number,
  amount: number,
  sigDeadline: number | BigNumber
) => {
  const message = ethers.utils.keccak256(
    ethers.utils.solidityPack(
      [
        "address",
        "bool",
        "uint256",
        "address",
        "uint256",
        "uint64",
        "string",
        "uint256",
        "address",
      ],
      [
        minter.address,
        free,
        price,
        payToken,
        nonce,
        sigDeadline,
        args,
        amount,
        ethers.constants.AddressZero,
      ]
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
    let priceFeed: MockChainlink;

    before(async () => {
      [deployer, hacker, user, ultimateAdmin] = await ethers.getSigners();
      priceFeed = (await (
        await ethers.getContractFactory("MockChainlink")
      ).deploy()) as unknown as MockChainlink;
      await priceFeed.deployed();

      nft = (await (
        await ethers.getContractFactory("CornersOfSpace")
      ).deploy(
        deployer.address,
        ultimateAdmin.address,
        deployer.address,
        priceFeed.address,
        "Corners of Space",
        "CoS",
        "uri"
      )) as CornersOfSpace;
      await nft.deployed();

      paymentToken = (await (await ethers.getContractFactory("TERC20"))
        .connect(user)
        .deploy("TERC20", "TERC20", 100)) as unknown as TERC20;
      await paymentToken.deployed();

      await nft.setReceivers(ultimateAdmin.address, deployer.address);
      await nft.setShare(liquidityShare, daoShare);
    });

    it("should transfer erc20 payment correctly", async () => {
      const deadline = await getSigDeadline();
      const balanceBefore = await paymentToken.balanceOf(deployer.address);
      const daoBalanceBefore = await paymentToken.balanceOf(
        ultimateAdmin.address
      );
      await paymentToken
        .connect(user)
        .approve(nft.address, ethers.utils.parseEther("100"));
      await nft
        .connect(user)
        .mint(
          false,
          paymentToken.address,
          price,
          nonce,
          deadline,
          await getMessage(
            deployer,
            user,
            false,
            price,
            paymentToken.address,
            nonce,
            deadline
          ),
          args,
          ethers.constants.AddressZero
        );
      nonce++;
      const balanceAfter = await paymentToken.balanceOf(deployer.address);
      const daoBalanceAfter = await paymentToken.balanceOf(
        ultimateAdmin.address
      );

      expect(await nft.ownerOf(1)).to.equal(user.address);
      expect(balanceAfter.sub(balanceBefore)).to.be.equal(
        price.mul(liquidityShare).div(100)
      );
      expect(daoBalanceAfter.sub(daoBalanceBefore)).to.be.equal(
        price.mul(daoShare).div(100)
      );
    });

    it("should transfer native token payment correctly", async () => {
      const deadline = await getSigDeadline();
      const value = price;
      const balanceBefore = await deployer.getBalance();
      const daoBalanceBefore = await ultimateAdmin.getBalance();
      await paymentToken
        .connect(user)
        .approve(nft.address, ethers.utils.parseEther("100"));
      await nft
        .connect(user)
        .mint(
          false,
          ethers.constants.AddressZero,
          price,
          nonce,
          deadline,
          await getMessage(
            deployer,
            user,
            false,
            price,
            ethers.constants.AddressZero,
            nonce,
            deadline
          ),
          args,
          ethers.constants.AddressZero,
          { value: value }
        );
      nonce++;
      const balanceAfter = await deployer.getBalance();
      const daoBalanceAfter = await ultimateAdmin.getBalance();

      expect(await nft.ownerOf(2)).to.equal(user.address);
      expect(balanceAfter.sub(balanceBefore)).to.be.equal(
        price.div(300).mul(liquidityShare).div(100)
      );
      expect(daoBalanceAfter.sub(daoBalanceBefore)).to.be.equal(
        price.div(300).mul(daoShare).div(100)
      );
    });

    it("should not let mint for native token if value isn't enough", async () => {
      const deadline = await getSigDeadline();
      const value = price.div(300);

      await expect(
        nft
          .connect(user)
          .mint(
            false,
            ethers.constants.AddressZero,
            price,
            nonce,
            deadline,
            await getMessage(
              deployer,
              user,
              false,
              price,
              ethers.constants.AddressZero,
              nonce,
              deadline
            ),
            args,
            ethers.constants.AddressZero,
            { value: value.sub(1) }
          )
      ).to.be.revertedWithCustomError(nft, "NotEnoughValue");
    });
    it("should let mint tokens correctly", async () => {
      const deadline = await getSigDeadline();
      await nft
        .connect(user)
        .mint(
          true,
          paymentToken.address,
          price,
          nonce,
          deadline,
          await getMessage(
            deployer,
            user,
            true,
            price,
            paymentToken.address,
            nonce,
            deadline
          ),
          args,
          ethers.constants.AddressZero
        );
      nonce++;

      expect(await nft.ownerOf(3)).to.equal(user.address);
    });
    it("should transfer erc20 payment correctly with referral in place", async () => {
      const deadline = await getSigDeadline();
      const balanceBefore = await paymentToken.balanceOf(deployer.address);
      const daoBalanceBefore = await paymentToken.balanceOf(
        ultimateAdmin.address
      );
      const referralBalanceBefore = await paymentToken.balanceOf(
        hacker.address
      );
      await paymentToken
        .connect(user)
        .approve(nft.address, ethers.utils.parseEther("100"));
      await nft
        .connect(user)
        .mint(
          false,
          paymentToken.address,
          price,
          nonce,
          deadline,
          await getMessage(
            deployer,
            user,
            false,
            price,
            paymentToken.address,
            nonce,
            deadline,
            hacker.address
          ),
          args,
          hacker.address
        );
      nonce++;
      const balanceAfter = await paymentToken.balanceOf(deployer.address);
      const daoBalanceAfter = await paymentToken.balanceOf(
        ultimateAdmin.address
      );
      const referralBalanceAfter = await paymentToken.balanceOf(hacker.address);

      expect(await nft.ownerOf(4)).to.equal(user.address);
      expect(balanceAfter.sub(balanceBefore)).to.be.equal(
        price.mul(liquidityShare - 5).div(100)
      );
      expect(daoBalanceAfter.sub(daoBalanceBefore)).to.be.equal(
        price.mul(daoShare).div(100)
      );
      expect(referralBalanceAfter.sub(referralBalanceBefore)).to.be.equal(
        price.mul(5).div(100)
      );
    });
    it("should transfer native token payment correctly with referral in place", async () => {
      const deadline = await getSigDeadline();
      const balanceBefore = await deployer.getBalance();
      const daoBalanceBefore = await ultimateAdmin.getBalance();
      const referralBalanceBefore = await hacker.getBalance();

      await nft
        .connect(user)
        .mint(
          false,
          ethers.constants.AddressZero,
          price,
          nonce,
          deadline,
          await getMessage(
            deployer,
            user,
            false,
            price,
            ethers.constants.AddressZero,
            nonce,
            deadline,
            hacker.address
          ),
          args,
          hacker.address,
          { value: price }
        );
      nonce++;
      const balanceAfter = await deployer.getBalance();
      const daoBalanceAfter = await ultimateAdmin.getBalance();
      const referralBalanceAfter = await hacker.getBalance();

      expect(await nft.ownerOf(5)).to.equal(user.address);
      expect(balanceAfter.sub(balanceBefore)).to.be.equal(
        price
          .div(300)
          .mul(liquidityShare - 5)
          .div(100)
      );
      expect(daoBalanceAfter.sub(daoBalanceBefore)).to.be.equal(
        price.div(300).mul(daoShare).div(100)
      );
      expect(referralBalanceAfter.sub(referralBalanceBefore)).to.be.equal(
        price.div(300).mul(5).div(100)
      );
    });
    it("should not let mint tokens if signer isn't verifier, but message is correct", async () => {
      const deadline = await getSigDeadline();

      await expect(
        nft
          .connect(user)
          .mint(
            true,
            paymentToken.address,
            price,
            nonce,
            deadline,
            await getMessage(
              user,
              user,
              true,
              price,
              paymentToken.address,
              nonce,
              deadline
            ),
            args,
            ethers.constants.AddressZero
          )
      ).to.be.revertedWithCustomError(nft, "UnauthorizedTx");
    });
    it("should not let mint tokens if signature expired", async () => {
      const deadline = await getSigDeadline();

      const message = await getMessage(
        user,
        user,
        true,
        price,
        paymentToken.address,
        nonce,
        deadline
      );
      await advanceBlock(101);
      await expect(
        nft
          .connect(user)
          .mint(
            true,
            paymentToken.address,
            price,
            nonce,
            deadline,
            message,
            args,
            ethers.constants.AddressZero
          )
      ).to.be.revertedWithCustomError(nft, "SigExpired");
    });

    it("should not let mint tokens if nonce has expired", async () => {
      const deadline = await getSigDeadline();
      await expect(
        nft
          .connect(user)
          .mint(
            true,
            paymentToken.address,
            price,
            nonce - 1,
            deadline,
            await getMessage(
              user,
              user,
              true,
              price,
              paymentToken.address,
              nonce - 1,
              deadline
            ),
            args,
            ethers.constants.AddressZero
          )
      ).to.be.revertedWithCustomError(nft, "InvalidNonce");
    });

    it("should let mint tokens in bundles", async () => {
      const deadline = await getSigDeadline();
      const balanceBefore = await paymentToken.balanceOf(deployer.address);
      const daoBalanceBefore = await paymentToken.balanceOf(
        ultimateAdmin.address
      );
      const amountToMint = 10;
      await nft
        .connect(user)
        .bundleMint(
          true,
          paymentToken.address,
          price,
          nonce,
          deadline,
          await getBundleMessage(
            deployer,
            user,
            true,
            price,
            paymentToken.address,
            nonce,
            amountToMint,
            deadline
          ),
          args,
          amountToMint,
          ethers.constants.AddressZero
        );
      nonce++;

      expect(await nft.ownerOf(6)).to.equal(user.address);
    });
    it("should let mint tokens in bundles and transfer erc20 correctly", async () => {
      const deadline = await getSigDeadline();

      const balanceBefore = await paymentToken.balanceOf(deployer.address);
      const daoBalanceBefore = await paymentToken.balanceOf(
        ultimateAdmin.address
      );

      const amountToMint = 10;
      await nft
        .connect(user)
        .bundleMint(
          false,
          paymentToken.address,
          price,
          nonce,
          deadline,
          await getBundleMessage(
            deployer,
            user,
            false,
            price,
            paymentToken.address,
            nonce,
            amountToMint,
            deadline
          ),
          args,
          amountToMint,
          ethers.constants.AddressZero
        );
      nonce++;

      expect(await nft.ownerOf(7)).to.equal(user.address);
      const balanceAfter = await paymentToken.balanceOf(deployer.address);
      const daoBalanceAfter = await paymentToken.balanceOf(
        ultimateAdmin.address
      );

      expect(balanceAfter.sub(balanceBefore)).to.be.equal(
        price.mul(liquidityShare).div(100)
      );
      expect(daoBalanceAfter.sub(daoBalanceBefore)).to.be.equal(
        price.mul(daoShare).div(100)
      );
    });
    it("should not let non-admin call updatePriceFeed", async () => {
      await expect(nft.connect(hacker).updatePriceFeed(hacker.address)).to.be
        .reverted;
    });
    it("should set new value with updatePriceFeed", async () => {
      await nft.updatePriceFeed(hacker.address);

      expect(await nft.bnbUSDFeed()).to.be.equal(hacker.address);
    });
    it("should not let non-admin call setReceiver", async () => {
      await expect(
        nft.connect(hacker).setReceivers(hacker.address, hacker.address)
      ).to.be.reverted;
    });
    it("should set new value with setReceiver", async () => {
      nft.setReceivers(hacker.address, hacker.address);
      expect(await nft.dao()).to.be.equal(hacker.address);
      expect(await nft.liquidityReceiver()).to.be.equal(hacker.address);

      await expect(
        nft.connect(hacker).setReceivers(hacker.address, hacker.address)
      ).to.be.reverted;
    });
    it("should not let non-admin call setTokenStatus", async () => {
      await expect(nft.connect(hacker).setPayTokenStatus(hacker.address, true))
        .to.be.reverted;
    });
    it("should set new value with setTokenStatus", async () => {
      await nft.setPayTokenStatus(hacker.address, true);

      expect(await nft.eligibleTokens(hacker.address)).to.be.equal(true);
    });
    it("should not let non-admin call setShare", async () => {
      await expect(nft.connect(hacker).setShare(100, 0)).to.be.reverted;
    });
    it("should set new value with setShare", async () => {
      await nft.setPayTokenStatus(hacker.address, true);

      expect(await nft.eligibleTokens(hacker.address)).to.be.equal(true);
    });
    it("should not let non-admin call setBaseURI", async () => {
      await expect(nft.connect(hacker).setBaseURI("YOINK")).to.be.reverted;
    });
    it("should not let non-admin call withdrawOwner", async () => {
      await expect(
        nft.connect(hacker).withdrawOwner(ethers.constants.AddressZero)
      ).to.be.reverted;
    });
    it("should let admin call withdrawOwner", async () => {
      await expect(nft.withdrawOwner(ethers.constants.AddressZero)).to.not.be
        .reverted;
    });
    it("should not let non-admin call setVerifier", async () => {
      await expect(nft.connect(hacker).setVerifier(hacker.address)).to.be
        .reverted;
    });
    it("should let admin set setVerifier", async () => {
      await nft.setVerifier(hacker.address);
      expect(await nft.verifier()).to.be.equal(hacker.address);
    });
  });
});
