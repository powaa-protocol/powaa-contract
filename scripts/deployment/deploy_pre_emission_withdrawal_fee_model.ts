/* eslint-disable no-console */
import hre from "hardhat";
import { PreEmissionFeeModel__factory } from "../../typechain";
import { assertEnvHOF, ETH_NETWORK, IEnv, save } from "../utils";

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();
  const BLOCK_NUMBER = await deployer?.provider?.getBlockNumber();

  // 2) Deploy PreEmission fee model
  console.log(">> 2. Deploying PreEmissionModel...");
  const PreEmissionModel = await new PreEmissionFeeModel__factory(
    deployer
  ).deploy();
  await PreEmissionModel.deployed();
  save(
    "pre_emission_fee_model",
    PreEmissionModel,
    LAYER_NETWORK,
    env,
    BLOCK_NUMBER
  );
  console.log(
    `>> ✅  Done Deploying PreEmissionModel Token with address ${PreEmissionModel.address}`
  );
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
