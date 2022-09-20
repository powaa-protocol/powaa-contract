import hre from "hardhat";
import { Timelock__factory } from "../../../typechain";
import { assertEnvHOF, ETH_NETWORK, getAddress, IEnv } from "../../utils";
import {
  executeTransaction,
  getJSON,
  ITimelockResponse,
  saveJSON,
} from "../../utils/timelock";

async function main() {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  let nonce = await deployer.getTransactionCount();
  const timelockTransactions: Array<ITimelockResponse> = [];
  const queueTransactions = getJSON<Array<ITimelockResponse>>(
    "1663158861_token_vaults_reduce_reserve", // file name to be executed
    LAYER_NETWORK,
    env
  );
  const Timelock = Timelock__factory.connect(
    getAddress("timelock", LAYER_NETWORK, env),
    deployer
  );
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  try {
    for (const queueTransaction of queueTransactions) {
      timelockTransactions.push(
        await executeTransaction(
          Timelock,
          queueTransaction.info,
          queueTransaction.queuedAt,
          queueTransaction.executionTransaction,
          queueTransaction.target,
          queueTransaction.value,
          queueTransaction.signature,
          queueTransaction.paramTypes,
          queueTransaction.params,
          queueTransaction.eta,
          {
            nonce: nonce++,
          }
        )
      );
    }
  } catch (e) {
    console.log(e);
  }

  saveJSON("timelock-execution", timelockTransactions, LAYER_NETWORK, env);
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
