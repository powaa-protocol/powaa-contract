/* eslint-disable no-console */

import hre, { ethers } from "hardhat";
import { Timelock__factory } from "../../../typechain";
import { IEnv, ETH_NETWORK, assertEnvHOF, getAddress } from "../../utils";
import {
  ITimelockResponse,
  queueTransaction,
  saveJSON,
} from "../../utils/timelock";

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  const govLpVaultAddress = getAddress("gov_lp_vault", LAYER_NETWORK, env);
  const timelockAddress = getAddress("timelock", LAYER_NETWORK, env);
  const gasPrice = ethers.utils.parseUnits("20", "gwei");
  const EXACT_ETA = "1663214400";

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  const timelockTransactions: Array<ITimelockResponse> = [];
  const Timelock = Timelock__factory.connect(timelockAddress, deployer);

  // 1) GovLPVault chainID 1 Migrate
  console.log(`>> Migrate ${govLpVaultAddress}`);
  timelockTransactions.push(
    await queueTransaction(
      Timelock,
      `migrate for govLPVault ${govLpVaultAddress}`,
      govLpVaultAddress,
      "0",
      "migrate()",
      [],
      [],
      EXACT_ETA,
      {
        gasPrice,
      }
    )
  );

  saveJSON("gov_lp_vault_migrate", timelockTransactions, LAYER_NETWORK, env);
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
