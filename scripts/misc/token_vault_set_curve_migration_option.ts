/* eslint-disable no-console */
import hre from "hardhat";
import {
  CurveLPVaultMigrator__factory,
  TokenVault__factory,
} from "../../typechain";
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
  // TokenVault Migration Options
  const tokenVaultAddress = getAddress(
    "token_vault-ETH-stETH_curve_lp",
    LAYER_NETWORK,
    env
  );
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
  const mapTokenVaultRouterParams = {
    curveLPRouter: getAddress(
      "ETH-stETH_curve_lp_swap_router",
      LAYER_NETWORK,
      env
    ),
    coinCount: 2,
  };

  const whitelistRouterToRemoveLiquidityAsEthParams = {
    curveLPRouter: getAddress(
      "ETH-stETH_curve_lp_swap_router",
      LAYER_NETWORK,
      env
    ),
    isLPContainETHCoin: true,
    ethIndex: 0,
    shouldUseUintParam: false,
  };
  const feeTier = 0;
  const TokenVault = TokenVault__factory.connect(tokenVaultAddress, deployer);
  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  // 1) Set Migration Option for TokenVault
  const [theMergeBlock, kinkFeeModelAddress, treasury, treasuryFeeRate] =
    await Promise.all([
      TokenVault.campaignEndBlock(),
      TokenVault.withdrawalFeeModel(),
      TokenVault.treasury(),
      TokenVault.treasuryFeeRate(),
    ]);
  console.log(">> 1. Set TokenVault Migration Option");
  const setTokenVaultMigrationOptionTx = await TokenVault.setMigrationOption(
    tokenVaultMigratorAddress,
    tokenVaultReserveMigratorAddress,
    theMergeBlock,
    kinkFeeModelAddress,
    feeTier,
    treasury,
    treasuryFeeRate
  );
  await setTokenVaultMigrationOptionTx.wait();
  console.log(
    `>> ✅  Done Set TokenVault Migration Option with tx: ${setTokenVaultMigrationOptionTx.hash}`
  );

  // 2.1) Whitelist TokenVault as a caller in TokenVault Migrator
  console.log(">> 2.1 Whitelist TokenVault in TokenVaultMigrator");
  const migratorWhitelistTokenVaultTx =
    await tokenVaultMigrator.whitelistTokenVault(tokenVaultAddress, true);
  await migratorWhitelistTokenVaultTx.wait();
  console.log(
    `>> ✅  Whitelist TokenVault to TokenVaultMigrator with tx: ${migratorWhitelistTokenVaultTx.hash}`
  );

  // 2.2) Setup Execution Parameters (whitelistRouterToRemoveLiquidityAsEth), (mapTokenVaultRouter)
  console.log(
    ">> 2.2.1 Map SwapRouter to Each TokenVault in TokenVaultMigrator"
  );
  const mapTokenVaultRouterTx = await tokenVaultMigrator.mapTokenVaultRouter(
    tokenVaultAddress,
    mapTokenVaultRouterParams.curveLPRouter,
    mapTokenVaultRouterParams.coinCount
  );
  await mapTokenVaultRouterTx.wait();
  console.log(
    `>> ✅  Map SwapRouter to Each TokenVault in TokenVaultMigrator with tx: ${mapTokenVaultRouterTx.hash}`
  );
  if (whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin) {
    console.log(
      ">> 2.2.2 Whitelist Router To Remove Liquidity As ETH (not using Uniswap V3, use Curve instead) in TokenVaultMigrator"
    );
    const whitelistRouterForRemovingUsingETHTx =
      await tokenVaultMigrator.whitelistRouterToRemoveLiquidityAsEth(
        whitelistRouterToRemoveLiquidityAsEthParams.curveLPRouter,
        whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin,
        whitelistRouterToRemoveLiquidityAsEthParams.ethIndex,
        whitelistRouterToRemoveLiquidityAsEthParams.shouldUseUintParam
      );
    await whitelistRouterForRemovingUsingETHTx.wait();
    console.log(
      `>> ✅  Whitelist Router To Remove Liquidity As ETH (not using Uniswap V3, use Curve instead) to TokenVaultMigrator with tx: ${whitelistRouterForRemovingUsingETHTx.hash}`
    );
  }

  // 3.1) Whitelist TokenVault as a caller in TokenVault Reserve Migrator
  console.log(">> 3.1 Whitelist TokenVault in TokenVaultReserveMigrator");
  const reserveMigratorWhitelistTokenVaultTx =
    await tokenVaultReserveMigrator.whitelistTokenVault(
      tokenVaultAddress,
      true
    );
  await reserveMigratorWhitelistTokenVaultTx.wait();
  console.log(
    `>> ✅  Whitelist TokenVault to TokenVaultReserveMigrator with tx: ${reserveMigratorWhitelistTokenVaultTx.hash}`
  );

  // 3.2) Setup Execution Parameters (whitelistRouterToRemoveLiquidityAsEth), (mapTokenVaultRouter)
  console.log(
    ">> 3.2.1 Map SwapRouter to Each TokenVault in TokenVaultReserveMigrator"
  );
  const mapTokenVaultRouterForReserveTx =
    await tokenVaultReserveMigrator.mapTokenVaultRouter(
      tokenVaultAddress,
      mapTokenVaultRouterParams.curveLPRouter,
      mapTokenVaultRouterParams.coinCount
    );
  await mapTokenVaultRouterForReserveTx.wait();
  console.log(
    `>> ✅  Map SwapRouter to Each TokenVault in TokenVaultReserveMigrator with tx: ${mapTokenVaultRouterForReserveTx.hash}`
  );
  if (whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin) {
    console.log(
      ">> 3.2.2 Whitelist Router To Remove Liquidity As ETH (not using Uniswap V3, use Curve instead) in TokenVaultReserveMigrator"
    );
    const whitelistRouterForRemovingUsingETHForReserveTx =
      await tokenVaultReserveMigrator.whitelistRouterToRemoveLiquidityAsEth(
        whitelistRouterToRemoveLiquidityAsEthParams.curveLPRouter,
        whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin,
        whitelistRouterToRemoveLiquidityAsEthParams.ethIndex,
        whitelistRouterToRemoveLiquidityAsEthParams.shouldUseUintParam
      );
    await whitelistRouterForRemovingUsingETHForReserveTx.wait();
    console.log(
      `>> ✅  Whitelist Router To Remove Liquidity As ETH (not using Uniswap V3, use Curve instead) to TokenVaultReserveMigrator with tx: ${whitelistRouterForRemovingUsingETHForReserveTx.hash}`
    );
  }

  // 4) Validations
  console.log(">> Validate TokenVault Params");
  console.table({
    withdrawalFeeModel: getEqAssertionObj(
      await TokenVault.withdrawalFeeModel(),
      kinkFeeModelAddress
    ),
    campaignEndBlock: getEqAssertionObj(
      (await TokenVault.campaignEndBlock()).toNumber(),
      theMergeBlock.toNumber()
    ),
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
    treasury: getEqAssertionObj(await TokenVault.treasury(), treasury),
    treasuryFeeRate: getEqAssertionObj(
      (await TokenVault.treasuryFeeRate()).toString(),
      treasuryFeeRate.toString()
    ),
  });

  console.log(">> Validate TokenVaultMigrator Params");
  console.table({
    tokenVaultPoolRouter: getEqAssertionObj(
      await tokenVaultMigrator.tokenVaultPoolRouter(tokenVaultAddress),
      mapTokenVaultRouterParams.curveLPRouter
    ),
    poolUnderlyingCount: getEqAssertionObj(
      (
        await tokenVaultMigrator.poolUnderlyingCount(
          mapTokenVaultRouterParams.curveLPRouter
        )
      ).toString(),
      mapTokenVaultRouterParams.coinCount.toString()
    ),
    stableSwapContainEth: getEqAssertionObj(
      await tokenVaultMigrator.stableSwapContainEth(
        mapTokenVaultRouterParams.curveLPRouter
      ),
      whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin
    ),
    ethIndex: getEqAssertionObj(
      (
        await tokenVaultMigrator.stableSwapEthMetadata(
          mapTokenVaultRouterParams.curveLPRouter
        )
      ).ethIndex.toString(),
      whitelistRouterToRemoveLiquidityAsEthParams.ethIndex.toString()
    ),
    shouldUseUintParam: getEqAssertionObj(
      (
        await tokenVaultMigrator.stableSwapEthMetadata(
          mapTokenVaultRouterParams.curveLPRouter
        )
      ).isUintParam,
      whitelistRouterToRemoveLiquidityAsEthParams.shouldUseUintParam
    ),
  });

  console.log(">> Validate TokenVaultReserveMigrator Params");
  console.table({
    tokenVaultPoolRouter: getEqAssertionObj(
      await tokenVaultReserveMigrator.tokenVaultPoolRouter(tokenVaultAddress),
      mapTokenVaultRouterParams.curveLPRouter
    ),
    poolUnderlyingCount: getEqAssertionObj(
      (
        await tokenVaultReserveMigrator.poolUnderlyingCount(
          mapTokenVaultRouterParams.curveLPRouter
        )
      ).toString(),
      mapTokenVaultRouterParams.coinCount.toString()
    ),
    stableSwapContainEth: getEqAssertionObj(
      await tokenVaultReserveMigrator.stableSwapContainEth(
        mapTokenVaultRouterParams.curveLPRouter
      ),
      whitelistRouterToRemoveLiquidityAsEthParams.isLPContainETHCoin
    ),
    ethIndex: getEqAssertionObj(
      (
        await tokenVaultReserveMigrator.stableSwapEthMetadata(
          mapTokenVaultRouterParams.curveLPRouter
        )
      ).ethIndex.toString(),
      whitelistRouterToRemoveLiquidityAsEthParams.ethIndex.toString()
    ),
    shouldUseUintParam: getEqAssertionObj(
      (
        await tokenVaultReserveMigrator.stableSwapEthMetadata(
          mapTokenVaultRouterParams.curveLPRouter
        )
      ).isUintParam,
      whitelistRouterToRemoveLiquidityAsEthParams.shouldUseUintParam
    ),
  });
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "develop", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
