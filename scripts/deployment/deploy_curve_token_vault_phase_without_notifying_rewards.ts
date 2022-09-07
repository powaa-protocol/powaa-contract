/* eslint-disable no-console */
import { expect } from "chai";
import { parseEther } from "ethers/lib/utils";
import hre, { ethers } from "hardhat";
import {
  Controller__factory,
  ERC20__factory,
  CurveLPVaultMigrator__factory,
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
  const THE_MERGE_BLOCK = 15539063; // block number where magic happens ✨
  // TokenVault Migration Options
  const tokenVaultRewardOptionParams = {
    rewardDuration: 691200, // 8 days
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
  const stakingToken = ERC20__factory.connect(stakingTokenAddress, deployer);
  const tokenVaultMigratorAddress = getAddress(
    "curve_lp_token_vault_migrator",
    LAYER_NETWORK,
    env
  );
  const tokenVaultMigrator = CurveLPVaultMigrator__factory.connect(
    tokenVaultMigratorAddress,
    deployer
  );
  const tokenVaultReserveMigratorAddress = getAddress(
    "curve_lp_token_vault_reserve_migrator",
    LAYER_NETWORK,
    env
  );
  const tokenVaultReserveMigrator = CurveLPVaultMigrator__factory.connect(
    tokenVaultReserveMigratorAddress,
    deployer
  );
  const feeTier = 0;
  const treasury = getAddress("treasury", LAYER_NETWORK, env);
  const treasuryFeeRate = ethers.utils.parseEther("0.1"); // Note that the 90% of the Withdrawal Fees generated will be converted to ETHW on PoW and used to pay for gas. The remaining 10% goes to the team.

  const mapTokenVaultRouterParams = {
    curveLPRouter: getAddress(
      "USDT-BTC-ETH_curve_lp_swap_router",
      LAYER_NETWORK,
      env
    ),
    coinCount: 3,
  };

  const whitelistRouterToRemoveLiquidityAsEthParams = {
    curveLPRouter: getAddress(
      "USDT-BTC-ETH_curve_lp_swap_router",
      LAYER_NETWORK,
      env
    ),
    isLPContainETHCoin: true,
    ethIndex: 2,
    shouldUseUintParam: true,
  };
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  // Sanity check
  const regex = new RegExp("_lp");
  if (!regex.test(stakingTokenSymbol)) {
    console.log(
      `>> Sanity check ${(
        await stakingToken.symbol()
      ).toLowerCase()} vs ${stakingTokenSymbol.toLowerCase()}`
    );
    expect(
      (await stakingToken.symbol()).toLowerCase(),
      stakingTokenSymbol.toLowerCase()
    );
  }
  // 1) Deploy TokenVault
  console.log(
    `>> 1. Deploying ${await stakingToken.symbol()} : ${await stakingToken.name()} : ${stakingTokenSymbol} TokenVault Contract...`
  );
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
    stakingTokenAddress,
    {
      gasPrice: ethers.utils.parseUnits("45", "gwei"),
    }
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
    tokenVaultMigratorAddress,
    tokenVaultReserveMigratorAddress,
    THE_MERGE_BLOCK,
    kinkFeeModelAddress,
    feeTier,
    treasury,
    treasuryFeeRate,
    {
      gasPrice: ethers.utils.parseUnits("45", "gwei"),
    }
  );
  await setTokenVaultMigrationOptionTx.wait();
  console.log(
    `>> ✅  Done Set TokenVault Migration Option with tx: ${setTokenVaultMigrationOptionTx.hash}`
  );

  // 3.1) Whitelist TokenVault as a caller in TokenVault Migrator
  console.log(">> 3.1 Whitelist TokenVault in TokenVaultMigrator");
  const migratorWhitelistTokenVaultTx =
    await tokenVaultMigrator.whitelistTokenVault(tokenVaultAddress, true, {
      gasPrice: ethers.utils.parseUnits("45", "gwei"),
    });
  await migratorWhitelistTokenVaultTx.wait();
  console.log(
    `>> ✅  Whitelist TokenVault to TokenVaultMigrator with tx: ${migratorWhitelistTokenVaultTx.hash}`
  );

  // 3.2) Setup Execution Parameters (whitelistRouterToRemoveLiquidityAsEth), (mapTokenVaultRouter)
  console.log(
    ">> 3.2.1 Map SwapRouter to Each TokenVault in TokenVaultMigrator"
  );
  const mapTokenVaultRouterTx = await tokenVaultMigrator.mapTokenVaultRouter(
    tokenVaultAddress,
    mapTokenVaultRouterParams.curveLPRouter,
    mapTokenVaultRouterParams.coinCount,
    {
      gasPrice: ethers.utils.parseUnits("45", "gwei"),
    }
  );
  await mapTokenVaultRouterTx.wait();
  console.log(
    `>> ✅  Map SwapRouter to Each TokenVault in TokenVaultMigrator with tx: ${mapTokenVaultRouterTx.hash}`
  );
  if (whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin) {
    console.log(
      ">> 3.2.2 Whitelist Router To Remove Liquidity As ETH (not using Uniswap V3, use Curve instead) in TokenVaultMigrator"
    );
    const whitelistRouterForRemovingUsingETHTx =
      await tokenVaultMigrator.whitelistRouterToRemoveLiquidityAsEth(
        whitelistRouterToRemoveLiquidityAsEthParams.curveLPRouter,
        whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin,
        whitelistRouterToRemoveLiquidityAsEthParams.ethIndex,
        whitelistRouterToRemoveLiquidityAsEthParams.shouldUseUintParam,
        {
          gasPrice: ethers.utils.parseUnits("45", "gwei"),
        }
      );
    await whitelistRouterForRemovingUsingETHTx.wait();
    console.log(
      `>> ✅  Whitelist Router To Remove Liquidity As ETH (not using Uniswap V3, use Curve instead) to TokenVaultMigrator with tx: ${whitelistRouterForRemovingUsingETHTx.hash}`
    );
  }

  // 4.1) Whitelist TokenVault as a caller in TokenVault Reserve Migrator
  console.log(">> 4.1 Whitelist TokenVault in TokenVaultReserveMigrator");
  const reserveMigratorWhitelistTokenVaultTx =
    await tokenVaultReserveMigrator.whitelistTokenVault(
      tokenVaultAddress,
      true,
      {
        gasPrice: ethers.utils.parseUnits("45", "gwei"),
      }
    );
  await reserveMigratorWhitelistTokenVaultTx.wait();
  console.log(
    `>> ✅  Whitelist TokenVault to TokenVaultReserveMigrator with tx: ${reserveMigratorWhitelistTokenVaultTx.hash}`
  );

  // 4.2) Setup Execution Parameters (whitelistRouterToRemoveLiquidityAsEth), (mapTokenVaultRouter)
  console.log(
    ">> 4.2.1 Map SwapRouter to Each TokenVault in TokenVaultReserveMigrator"
  );
  const mapTokenVaultRouterForReserveTx =
    await tokenVaultReserveMigrator.mapTokenVaultRouter(
      tokenVaultAddress,
      mapTokenVaultRouterParams.curveLPRouter,
      mapTokenVaultRouterParams.coinCount,
      {
        gasPrice: ethers.utils.parseUnits("45", "gwei"),
      }
    );
  await mapTokenVaultRouterForReserveTx.wait();
  console.log(
    `>> ✅  Map SwapRouter to Each TokenVault in TokenVaultReserveMigrator with tx: ${mapTokenVaultRouterForReserveTx.hash}`
  );
  if (whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin) {
    console.log(
      ">> 4.2.2 Whitelist Router To Remove Liquidity As ETH (not using Uniswap V3, use Curve instead) in TokenVaultReserveMigrator"
    );
    const whitelistRouterForRemovingUsingETHForReserveTx =
      await tokenVaultReserveMigrator.whitelistRouterToRemoveLiquidityAsEth(
        whitelistRouterToRemoveLiquidityAsEthParams.curveLPRouter,
        whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin,
        whitelistRouterToRemoveLiquidityAsEthParams.ethIndex,
        whitelistRouterToRemoveLiquidityAsEthParams.shouldUseUintParam,
        {
          gasPrice: ethers.utils.parseUnits("45", "gwei"),
        }
      );
    await whitelistRouterForRemovingUsingETHForReserveTx.wait();
    console.log(
      `>> ✅  Whitelist Router To Remove Liquidity As ETH (not using Uniswap V3, use Curve instead) to TokenVaultReserveMigrator with tx: ${whitelistRouterForRemovingUsingETHForReserveTx.hash}`
    );
  }

  // 5) Set setRewardsDuration to be aligned with the MERGE time in unix timestamp
  console.log(
    ">> 5. Set setRewardsDuration to be aligned with the MERGE time in unix timestamp"
  );
  const setRewardsDurationTx = await TokenVault__factory.connect(
    tokenVaultAddress,
    deployer
  ).setRewardsDuration(tokenVaultRewardOptionParams.rewardDuration, {
    gasPrice: ethers.utils.parseUnits("45", "gwei"),
  });
  await setRewardsDurationTx.wait();
  console.log(
    `>> ✅  Done Set setRewardsDuration to be aligned with the MERGE time in unix timestamp with tx: ${setRewardsDurationTx.hash}`
  );

  // 6) Validations
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
      "0"
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
      tokenVaultMigratorAddress
    ),
    reserveMigrator: getEqAssertionObj(
      await TokenVault.reserveMigrator(),
      tokenVaultReserveMigratorAddress
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

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
