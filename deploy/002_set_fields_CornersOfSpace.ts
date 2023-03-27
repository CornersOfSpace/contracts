import { DeployFunction, DeploymentsExtension } from "hardhat-deploy/types";

export const createExecuteWithLog =
  (execute: DeploymentsExtension["execute"]) =>
  async (...args: Parameters<DeploymentsExtension["execute"]>) => {
    const [contractName, , methodName] = args;

    console.log(`executing "${contractName}.${methodName}"`);

    const receipt = await execute.apply(execute, args);

    console.log(
      `tx "${contractName}.${methodName}": ${receipt.transactionHash}`
    );

    return receipt;
  };

const deploy: DeployFunction = async ({ deployments, getNamedAccounts }) => {
  const { deployer } = await getNamedAccounts();

  const CoS = await deployments.get("CornersOfSpace");

  const executeWithLog = createExecuteWithLog(deployments.execute);

  await executeWithLog(
    "CornersOfSpace",
    { from: deployer },
    "setShare",
    process.env.LIQUIDITY_SHARE,
    process.env.DAO_SHARE
  );

  await executeWithLog(
    "CornersOfSpace",
    { from: deployer },
    "setReceivers",
    process.env.DAO,
    process.env.LIQUIDITY_RECEIVER
  );

  await executeWithLog(
    "CornersOfSpace",
    { from: deployer },
    "setPayTokenStatus",
    process.env.PAY_TOKEN_1,
    true
  );

  await executeWithLog(
    "CornersOfSpace",
    { from: deployer },
    "setPayTokenStatus",
    process.env.PAY_TOKEN_2,
    true
  );

  await executeWithLog(
    "CornersOfSpace",
    { from: deployer },
    "setPayTokenStatus",
    process.env.PAY_TOKEN_3,
    true
  );
};

deploy.tags = ["main", "setCornersOfSpace"];
deploy.dependencies = ["CornersOfSpace"];

export default deploy;
