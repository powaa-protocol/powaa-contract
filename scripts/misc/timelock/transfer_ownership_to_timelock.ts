import hre from "hardhat";
import { Ownable__factory, Timelock__factory } from "../../../typechain";
import {
  assertEnvHOF,
  ETH_NETWORK,
  getAddress,
  getEqAssertionObj,
  IEnv,
} from "../../utils";

async function main() {
  /*
  ░██╗░░░░░░░██╗░█████╗░██████╗░███╗░░██╗██╗███╗░░██╗░██████╗░
  ░██║░░██╗░░██║██╔══██╗██╔══██╗████╗░██║██║████╗░██║██╔════╝░
  ░╚██╗████╗██╔╝███████║██████╔╝██╔██╗██║██║██╔██╗██║██║░░██╗░
  ░░████╔═████║░██╔══██║██╔══██╗██║╚████║██║██║╚████║██║░░╚██╗
  ░░╚██╔╝░╚██╔╝░██║░░██║██║░░██║██║░╚███║██║██║░╚███║╚██████╔╝
  ░░░╚═╝░░░╚═╝░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝╚═╝╚═╝░░╚══╝░╚═════╝░
  Check all variables below before execute the deployment script
  */

  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();
  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  const govLPVaultImplAddress = getAddress(
    "gov_lp_vault_impl",
    LAYER_NETWORK,
    env
  );
  const tokenVaultImplAddress = getAddress(
    "token_vault_impl",
    LAYER_NETWORK,
    env
  );
  const TO_BE_TRANSFERED: Array<string> = [tokenVaultImplAddress];
  const timelockAddress = getAddress("timelock", LAYER_NETWORK, env);
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  for (let i = 0; i < TO_BE_TRANSFERED.length; i++) {
    console.log(
      `>> ${i} Transferring ownership of ${TO_BE_TRANSFERED[i]} to Timelock ${timelockAddress}`
    );
    const ownable = Ownable__factory.connect(TO_BE_TRANSFERED[i], deployer);
    const tx = await ownable.transferOwnership(timelockAddress);
    await tx.wait();
    console.log(`>> tx hash: ${tx.hash}`);
    console.log("✅ Done");
    console.log(">> Validate TokenVault Ownership");
    console.table({
      owner: getEqAssertionObj(await ownable.owner(), timelockAddress),
    });
    console.log(
      `>> ✅ Done Transferring ownership of ${TO_BE_TRANSFERED[i]} to Timelock ${timelockAddress}`
    );
  }
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
