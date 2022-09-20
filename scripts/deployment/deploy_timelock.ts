/* eslint-disable no-console */
import hre from "hardhat";
import { Timelock__factory } from "../../typechain";
import { assertEnvHOF, ETH_NETWORK, IEnv, save } from "../utils";

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();
  const BLOCK_NUMBER = await deployer?.provider?.getBlockNumber();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  const timelockParams = {
    admin: await deployer.getAddress(),
    delay: 21600, // 6 hours
  };

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  console.log(">> Deploying Timelock...");
  const Timelock = await new Timelock__factory(deployer).deploy(
    timelockParams.admin,
    timelockParams.delay
  );
  await Timelock.deployed();
  save("timelock", Timelock, LAYER_NETWORK, env, BLOCK_NUMBER);
  console.log(
    `>> ✅  Done Deploying Timelock with address ${Timelock.address}`
  );
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
