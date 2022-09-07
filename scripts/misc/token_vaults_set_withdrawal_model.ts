/* eslint-disable no-console */
import hre, { ethers } from "hardhat";
import { TokenVault__factory } from "../../typechain";
import {
  assertEnvHOF,
  ETH_NETWORK,
  getAddress,
  getEqAssertionObj,
  IEnv,
} from "../utils";

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  const withdrawalFeeModelAddress = getAddress(
    "kink_fee_model",
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

  const gasPrice = ethers.utils.parseUnits("12", "gwei");

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  for (let i = 0; i < tokenVaultAddresses.length; i++) {
    const tokenVaultAddress = tokenVaultAddresses[i];
    // 1) TokenVault Notify reward amount based on rewardsDuration * rewardPerSec
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
      theMergeBlock: theMergeBlock.toString(),
      feePool: feePool.toString(),
      treasury,
      treasuryFeeRate: treasuryFeeRate.toString(),
      prevWithdrawalFeeModelAddress: prevWithdrawalFeeModel,
      withdrawalFeeModelAddress: withdrawalFeeModelAddress,
    });
    const setWithdrawalFeeModel = await TokenVault.setMigrationOption(
      migrator,
      reserveMigrator,
      theMergeBlock,
      withdrawalFeeModelAddress,
      feePool,
      treasury,
      treasuryFeeRate,
      {
        gasPrice,
      }
    );
    await setWithdrawalFeeModel.wait();
    console.log(
      `>> ✅ Done Set withdrawal fee model to be ${withdrawalFeeModelAddress} with tx : ${setWithdrawalFeeModel}`
    );

    // 2) Validations
    console.log(">> Validate TokenVault Params");
    console.table({
      withdrawalFeeModel: getEqAssertionObj(
        await TokenVault.withdrawalFeeModel(),
        withdrawalFeeModelAddress
      ),
      campaignEndBlock: getEqAssertionObj(
        (await TokenVault.campaignEndBlock()).toNumber(),
        theMergeBlock.toNumber()
      ),
      feePool: getEqAssertionObj(
        (await TokenVault.feePool()).toString(),
        feePool.toString()
      ),
      migrator: getEqAssertionObj(await TokenVault.migrator(), migrator),
      reserveMigrator: getEqAssertionObj(
        await TokenVault.reserveMigrator(),
        reserveMigrator
      ),
      treasury: getEqAssertionObj(await TokenVault.treasury(), treasury),
      treasuryFeeRate: getEqAssertionObj(
        (await TokenVault.treasuryFeeRate()).toString(),
        treasuryFeeRate.toString()
      ),
    });
    console.log(
      `campaign start block: ${(
        await TokenVault.campaignStartBlock()
      ).toString()}`
    );
    console.log(`periodFinish: ${await TokenVault.periodFinish()}`);
  }
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
