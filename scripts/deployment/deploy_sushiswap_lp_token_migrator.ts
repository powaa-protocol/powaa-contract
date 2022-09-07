/* eslint-disable no-console */
import { parseEther } from "ethers/lib/utils";
import hre from "hardhat";
import { SushiSwapLPVaultMigrator__factory } from "../../typechain";
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

  const controllerAddress = getAddress("controller", LAYER_NETWORK, env);
  const govLpVaultAddress = getAddress("gov_lp_vault", LAYER_NETWORK, env);

  // TokenVault Migrator
  const tokenVaultMigratorParams = {
    sushiswapRouter: getAddress("sushiswap_router", LAYER_NETWORK, env),
    uniswapV3router: getAddress("uniswap_v3_router_02", LAYER_NETWORK, env),
    govLpVaultFeeRate: parseEther("0.25"), // 25% of all the acquired ETHW will be distributed to the liquidity providers of the POWAA-ETH LP
    treasuryFeeRate: parseEther("0.1"), // 10% of all the acquired ETHW will be distributed among the team as an incentive for the Powaa Protocol team
    treasuryAccount: getAddress("treasury", LAYER_NETWORK, env),
    controllerFeeRate: parseEther("0.05"), // 5% of all the ETHW acquired using the deposit vaults
    quoter: getAddress("uniswap_v3_quoter", LAYER_NETWORK, env),
  };

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  // 1) Deploy TokenVault Migrator
  console.log(">> 1. Deploying Sushiswap LP TokenVault Migrator Contract...");
  const TokenVaultMigrator = await new SushiSwapLPVaultMigrator__factory(
    deployer
  ).deploy(
    tokenVaultMigratorParams.treasuryAccount,
    controllerAddress,
    govLpVaultAddress,
    tokenVaultMigratorParams.treasuryFeeRate,
    tokenVaultMigratorParams.controllerFeeRate,
    tokenVaultMigratorParams.govLpVaultFeeRate,
    tokenVaultMigratorParams.sushiswapRouter,
    tokenVaultMigratorParams.uniswapV3router,
    tokenVaultMigratorParams.quoter
  );
  await TokenVaultMigrator.deployed();
  save(
    "sushiswap_lp_vault_migrator",
    TokenVaultMigrator,
    LAYER_NETWORK,
    env,
    BLOCK_NUMBER
  );
  console.log(
    `>> ✅  Done Deploying Sushiswap LP TokenVault Migrator Contract with address ${TokenVaultMigrator.address}`
  );

  console.table({
    treasury: getEqAssertionObj(
      (await TokenVaultMigrator.treasury()).toString(),
      tokenVaultMigratorParams.treasuryAccount
    ),
    controller: getEqAssertionObj(
      (await TokenVaultMigrator.controller()).toString(),
      controllerAddress
    ),
    govLpVault: getEqAssertionObj(
      (await TokenVaultMigrator.govLPTokenVault()).toString(),
      govLpVaultAddress
    ),
    sushiswapRouter: getEqAssertionObj(
      (await TokenVaultMigrator.sushiSwapRouter()).toString(),
      tokenVaultMigratorParams.sushiswapRouter
    ),
    univ3Router: getEqAssertionObj(
      (await TokenVaultMigrator.uniswapRouter()).toString(),
      tokenVaultMigratorParams.uniswapV3router
    ),
    treasuryFeeRate: getEqAssertionObj(
      (await TokenVaultMigrator.treasuryFeeRate()).toString(),
      tokenVaultMigratorParams.treasuryFeeRate.toString()
    ),
    controllerFeeRate: getEqAssertionObj(
      (await TokenVaultMigrator.controllerFeeRate()).toString(),
      tokenVaultMigratorParams.controllerFeeRate.toString()
    ),
    govLpVaultFeeRate: getEqAssertionObj(
      (await TokenVaultMigrator.govLPTokenVaultFeeRate()).toString(),
      tokenVaultMigratorParams.govLpVaultFeeRate.toString()
    ),
  });

  // 2) Deploy TokenVault Migrator
  console.log(
    ">> 2. Deploying Sushiswap LP TokenVault Reserve Migrator Contract..."
  );
  const TokenVaultReserveMigrator = await new SushiSwapLPVaultMigrator__factory(
    deployer
  ).deploy(
    tokenVaultMigratorParams.treasuryAccount,
    controllerAddress,
    govLpVaultAddress,
    0,
    0,
    0,
    tokenVaultMigratorParams.sushiswapRouter,
    tokenVaultMigratorParams.uniswapV3router,
    tokenVaultMigratorParams.quoter
  );
  await TokenVaultReserveMigrator.deployed();
  save(
    "sushiswap_lp_vault_reserve_migrator",
    TokenVaultReserveMigrator,
    LAYER_NETWORK,
    env,
    BLOCK_NUMBER
  );
  console.log(
    `>> ✅  Done Deploying Sushiswap LP TokenVault Reserve Migrator Contract with address ${TokenVaultReserveMigrator.address}`
  );

  console.table({
    treasury: getEqAssertionObj(
      (await TokenVaultReserveMigrator.treasury()).toString(),
      tokenVaultMigratorParams.treasuryAccount
    ),
    controller: getEqAssertionObj(
      (await TokenVaultReserveMigrator.controller()).toString(),
      controllerAddress
    ),
    govLpVault: getEqAssertionObj(
      (await TokenVaultReserveMigrator.govLPTokenVault()).toString(),
      govLpVaultAddress
    ),
    sushiswapRouter: getEqAssertionObj(
      (await TokenVaultReserveMigrator.sushiSwapRouter()).toString(),
      tokenVaultMigratorParams.sushiswapRouter
    ),
    univ3Router: getEqAssertionObj(
      (await TokenVaultReserveMigrator.uniswapRouter()).toString(),
      tokenVaultMigratorParams.uniswapV3router
    ),
    treasuryFeeRate: getEqAssertionObj(
      (await TokenVaultReserveMigrator.treasuryFeeRate()).toString(),
      "0"
    ),
    controllerFeeRate: getEqAssertionObj(
      (await TokenVaultReserveMigrator.controllerFeeRate()).toString(),
      "0"
    ),
    govLpVaultFeeRate: getEqAssertionObj(
      (await TokenVaultReserveMigrator.govLPTokenVaultFeeRate()).toString(),
      "0"
    ),
  });
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
