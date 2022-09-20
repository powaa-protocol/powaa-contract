/* eslint-disable no-console */

import hre, { ethers } from "hardhat";
import { Timelock__factory, TokenVault__factory } from "../../../typechain";
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
  const withdrawalFeeModelAddress = getAddress(
    "pre_emission_fee_model",
    LAYER_NETWORK,
    env
  );
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
  const campaignEndBlock = 15538847;

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  const timelockTransactions: Array<ITimelockResponse> = [];
  const Timelock = Timelock__factory.connect(timelockAddress, deployer);

  for (let i = 0; i < tokenVaultAddresses.length; i++) {
    const tokenVaultAddress = tokenVaultAddresses[i];
    console.log(
      `>> ${i}. Set withdrawal fee model to be ${withdrawalFeeModelAddress} for ${tokenVaultAddress}`
    );
    const TokenVault = TokenVault__factory.connect(tokenVaultAddress, deployer);
    const [
      migrator,
      reserveMigrator,
      theMergeBlock,
      prevWithdrawalFeeModel,
      feePool,
      treasury,
      treasuryFeeRate,
    ] = await Promise.all([
      TokenVault.migrator(),
      TokenVault.reserveMigrator(),
      TokenVault.campaignEndBlock(),
      TokenVault.withdrawalFeeModel(),
      TokenVault.feePool(),
      TokenVault.treasury(),
      TokenVault.treasuryFeeRate(),
    ]);
    console.table({
      migrator,
      reserveMigrator,
      campaignEndBlock: campaignEndBlock.toString(),
      feePool: feePool.toString(),
      treasury,
      treasuryFeeRate: treasuryFeeRate.toString(),
      prevWithdrawalFeeModelAddress: prevWithdrawalFeeModel,
      withdrawalFeeModelAddress: withdrawalFeeModelAddress,
    });
    timelockTransactions.push(
      await queueTransaction(
        Timelock,
        `set withdrawal fee for vault ${tokenVaultAddress}`,
        tokenVaultAddress,
        "0",
        "setMigrationOption(address,address,uint256,address,uint24,address,uint256)",
        [
          "address",
          "address",
          "uint256",
          "address",
          "uint24",
          "address",
          "uint256",
        ],
        [
          migrator,
          reserveMigrator,
          campaignEndBlock.toString(),
          withdrawalFeeModelAddress,
          feePool.toString(),
          treasury,
          treasuryFeeRate.toString(),
        ],
        EXACT_ETA,
        {
          gasPrice,
        }
      )
    );
  }

  saveJSON(
    "token_vaults_set_withdrawal_model",
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
