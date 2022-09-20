/* eslint-disable no-console */
import { BigNumber } from "ethers";
import hre from "hardhat";
import { Controller__factory } from "../../typechain";
import { assertEnvHOF, ETH_NETWORK, getAddress, IEnv } from "../utils";

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  const controller = Controller__factory.connect(
    getAddress("controller", LAYER_NETWORK, env),
    deployer
  );
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  const approx =
    await controller.callStatic.getApproximatedTotalExecutionRewards();
  console.log("approx reward: ", approx.toString());
  const tx = await controller.migrate({
    gasLimit: BigNumber.from("26000000"),
  });
  await tx.wait();

  console.log(`>> ✅ Done with ${tx.hash}`);
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
