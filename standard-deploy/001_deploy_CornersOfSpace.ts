import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async ({
  deployments: { deploy },
  getNamedAccounts,
}) => {
  const { deployer } = await getNamedAccounts();

  await deploy("CornersOfSpace", {
    from: deployer,
    log: true,
    args: [
      process.env.ADMIN_ADDRESS,
      process.env.ULTIMATE_ADMIN_ADDRESS,
      process.env.VERIFIER_ADDRESS,
      process.env.PRICE_FEED,
      process.env.NFT_NAME,
      process.env.NFT_SYMBOL,
      process.env.BASE_URI,
    ],
  });
};

deploy.tags = ["main", "CornersOfSpace"];

export default deploy;
