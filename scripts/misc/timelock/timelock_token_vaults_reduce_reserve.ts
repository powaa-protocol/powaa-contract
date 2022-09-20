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
  const tokenVaultAddresses = [
    getAddress("token_vault-1INCH", LAYER_NETWORK, env),
    getAddress("token_vault-AAVE", LAYER_NETWORK, env),
    getAddress("token_vault-APE", LAYER_NETWORK, env),
    getAddress("token_vault-BIT", LAYER_NETWORK, env),
    getAddress("token_vault-BTC-ETH_sushiswap_lp", LAYER_NETWORK, env),
    getAddress("token_vault-COMP", LAYER_NETWORK, env),
    getAddress("token_vault-CRV", LAYER_NETWORK, env),
    getAddress("token_vault-CVX", LAYER_NETWORK, env),
    getAddress("token_vault-DAI-USDC-USDT_curve_lp", LAYER_NETWORK, env),
    getAddress("token_vault-DAI", LAYER_NETWORK, env),
    getAddress("token_vault-ETH-stETH_curve_lp", LAYER_NETWORK, env),
    getAddress("token_vault-LDO", LAYER_NETWORK, env),
    getAddress("token_vault-LINK", LAYER_NETWORK, env),
    getAddress("token_vault-LOOKS", LAYER_NETWORK, env),
    getAddress("token_vault-MATIC", LAYER_NETWORK, env),
    getAddress("token_vault-MKR", LAYER_NETWORK, env),
    getAddress("token_vault-SHIB", LAYER_NETWORK, env),
    getAddress("token_vault-SUSHI-ETH_sushiswap_lp", LAYER_NETWORK, env),
    getAddress("token_vault-UNI", LAYER_NETWORK, env),
    getAddress("token_vault-USDC-ETH_sushiswap_lp", LAYER_NETWORK, env),
    getAddress("token_vault-USDC", LAYER_NETWORK, env),
    getAddress("token_vault-USDT-BTC-ETH_curve_lp", LAYER_NETWORK, env),
    getAddress("token_vault-USDT-ETH_sushiswap_lp", LAYER_NETWORK, env),
    getAddress("token_vault-USDT", LAYER_NETWORK, env),
    getAddress("token_vault-WBTC", LAYER_NETWORK, env),
  ];
  const timelockAddress = getAddress("timelock", LAYER_NETWORK, env);
  const gasPrice = ethers.utils.parseUnits("12", "gwei");
  const EXACT_ETA = "1663214400";

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  const timelockTransactions: Array<ITimelockResponse> = [];
  const Timelock = Timelock__factory.connect(timelockAddress, deployer);

  for (let i = 0; i < tokenVaultAddresses.length; i++) {
    const tokenVaultAddress = tokenVaultAddresses[i];
    // 1) TokenVault reduce reserve
    console.log(`>> ${i}. Reduce reserve for ${tokenVaultAddress}`);
    timelockTransactions.push(
      await queueTransaction(
        Timelock,
        `reduce reserve for vault ${tokenVaultAddress}`,
        tokenVaultAddress,
        "0",
        "reduceReserve()",
        [],
        [],
        EXACT_ETA,
        {
          gasPrice,
        }
      )
    );
  }

  saveJSON(
    "token_vaults_reduce_reserve",
    timelockTransactions,
    LAYER_NETWORK,
    env
  );
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
