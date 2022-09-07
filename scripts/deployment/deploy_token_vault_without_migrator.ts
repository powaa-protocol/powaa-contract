/* eslint-disable no-console */
import { constants } from "ethers";
import { parseEther } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";
import {
  Controller__factory,
  POWAA__factory,
  TokenVault__factory,
} from "../../typechain";
import {
  assertEnvHOF,
  ETH_NETWORK,
  getAddress,
  getEqAssertionObj,
  IEnv,
  save,
} from "../utils";

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();
  const BLOCK_NUMBER = await deployer?.provider?.getBlockNumber();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  const THE_MERGE_BLOCK = 16000000; // block number where magic happens ✨
  const tokenVaultTotalIncentives = parseEther("520000000000"); // 520,000,000,000.00
  // TokenVault Migration Options
  const tokenVaultRewardOptionParams = {
    rewardDuration: 604800, // 1 week
    rewardAmount: tokenVaultTotalIncentives,
  };
  const Controller = Controller__factory.connect(
    getAddress("controller", LAYER_NETWORK, env),
    deployer
  );
  const tokenVaultImplAddress = getAddress(
    "token_vault_impl",
    LAYER_NETWORK,
    env
  );
  const powaaAddress = getAddress("POWAA", LAYER_NETWORK, env);
  const kinkFeeModelAddress = getAddress("kink_fee_model", LAYER_NETWORK, env);
  const stakingTokenSymbol = "USDT-BTC-ETH_curve_lp";
  const stakingTokenAddress = getAddress(
    stakingTokenSymbol,
    LAYER_NETWORK,
    env
  );
  const feeTier = 0;
  const treasury = getAddress("treasury", LAYER_NETWORK, env);
  const treasuryFeeRate = ethers.utils.parseEther("0.1"); // Note that the 90% of the Withdrawal Fees generated will be converted to ETHW on PoW and used to pay for gas. The remaining 10% goes to the team.

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  // 1) Deploy TokenVault
  console.log(">> 1. Deploying TokenVault Contract...");
  const tokenVaultAddress = await Controller.getDeterministicVault(
    tokenVaultImplAddress,
    stakingTokenAddress
  );
  save(
    `token_vault-${stakingTokenSymbol}`,
    { address: tokenVaultAddress },
    LAYER_NETWORK,
    env,
    BLOCK_NUMBER
  );
  const deployTokenVaultTx = await Controller.deployDeterministicVault(
    tokenVaultImplAddress,
    await deployer.getAddress(),
    powaaAddress,
    stakingTokenAddress
  );
  await deployTokenVaultTx.wait();
  console.log(
    `>> ✅  Done Deploying TokenVault Contract with tx: ${deployTokenVaultTx.hash} with address ${tokenVaultAddress}`
  );

  // 2) Set Migration Option for TokenVault
  console.log(">> 2. Set TokenVault Migration Option");
  const setTokenVaultMigrationOptionTx = await TokenVault__factory.connect(
    tokenVaultAddress,
    deployer
  ).setMigrationOption(
    constants.AddressZero,
    constants.AddressZero,
    THE_MERGE_BLOCK,
    kinkFeeModelAddress,
    feeTier,
    treasury,
    treasuryFeeRate
  );
  await setTokenVaultMigrationOptionTx.wait();
  console.log(
    `>> ✅  Done Set TokenVault Migration Option with tx: ${setTokenVaultMigrationOptionTx.hash}`
  );

  // 3) Set setRewardsDuration to be aligned with the MERGE time in unix timestamp
  console.log(
    ">> 3. Set setRewardsDuration to be aligned with the MERGE time in unix timestamp"
  );
  const setRewardsDurationTx = await TokenVault__factory.connect(
    tokenVaultAddress,
    deployer
  ).setRewardsDuration(tokenVaultRewardOptionParams.rewardDuration);
  await setRewardsDurationTx.wait();
  console.log(
    `>> ✅  Done Set setRewardsDuration to be aligned with the MERGE time in unix timestamp with tx: ${setRewardsDurationTx.hash}`
  );

  // 4) TokenVault Notify reward amount based on rewardsDuration * rewardPerSec
  console.log(
    `>> 4. Notify reward amount ${tokenVaultRewardOptionParams.rewardAmount.toString()}`
  );
  const transferTX = await POWAA__factory.connect(
    powaaAddress,
    deployer
  ).transfer(tokenVaultAddress, tokenVaultRewardOptionParams.rewardAmount);
  await transferTX.wait();
  const notifyRewardAmountTx = await TokenVault__factory.connect(
    tokenVaultAddress,
    deployer
  ).notifyRewardAmount(tokenVaultRewardOptionParams.rewardAmount);
  await notifyRewardAmountTx.wait();
  console.log(
    `>> ✅ Done Notify reward amount ${tokenVaultRewardOptionParams.rewardAmount.toString()} with transfer tx: ${
      transferTX.hash
    } and notify tx: ${notifyRewardAmountTx.hash}`
  );

  // 5) Validations
  const TokenVault = TokenVault__factory.connect(tokenVaultAddress, deployer);

  console.log(">> Validate Controller's TokenVault");
  console.table({
    registeredVaults: getEqAssertionObj(
      await Controller.registeredVaults(TokenVault.address),
      true
    ),
  });

  console.log(">> Validate TokenVault Params");
  console.table({
    masterContract: getEqAssertionObj(
      await TokenVault.masterContract(),
      tokenVaultImplAddress
    ),
    WETH9: getEqAssertionObj(
      await TokenVault.WETH9(),
      getAddress("WETH9", LAYER_NETWORK, env)
    ),
    rewardsDistribution: getEqAssertionObj(
      await TokenVault.rewardsDistribution(),
      await deployer.getAddress()
    ),
    rewardsToken: getEqAssertionObj(
      await TokenVault.rewardsToken(),
      powaaAddress
    ),
    stakingToken: getEqAssertionObj(
      await TokenVault.stakingToken(),
      stakingTokenAddress
    ),
    rewardRate: getEqAssertionObj(
      (await TokenVault.rewardRate()).toString(),
      tokenVaultRewardOptionParams.rewardAmount
        .div(tokenVaultRewardOptionParams.rewardDuration)
        .toString()
    ),
    rewardsDuration: getEqAssertionObj(
      (await TokenVault.rewardsDuration()).toNumber(),
      tokenVaultRewardOptionParams.rewardDuration
    ),
    withdrawalFeeModel: getEqAssertionObj(
      await TokenVault.withdrawalFeeModel(),
      kinkFeeModelAddress
    ),
    isGovLpVault: getEqAssertionObj(await TokenVault.isGovLpVault(), false),
    isMigrated: getEqAssertionObj(await TokenVault.isMigrated(), false),
    campaignEndBlock: getEqAssertionObj(
      (await TokenVault.campaignEndBlock()).toNumber(),
      THE_MERGE_BLOCK
    ),
    reserve: getEqAssertionObj((await TokenVault.reserve()).toString(), "0"),
    feePool: getEqAssertionObj(
      (await TokenVault.feePool()).toString(),
      feeTier.toString()
    ),
    migrator: getEqAssertionObj(
      await TokenVault.migrator(),
      constants.AddressZero
    ),
    reserveMigrator: getEqAssertionObj(
      await TokenVault.reserveMigrator(),
      constants.AddressZero
    ),
    controller: getEqAssertionObj(
      await TokenVault.controller(),
      Controller.address
    ),
  });
  console.log(
    `campaign start block: ${(
      await TokenVault.campaignStartBlock()
    ).toString()}`
  );
  console.log(`periodFinish: ${await TokenVault.periodFinish()}`);
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "develop", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
