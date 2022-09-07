/* eslint-disable no-console */
import { parseEther } from "ethers/lib/utils";
import hre from "hardhat";
import {
  Controller__factory,
  GovLPVault__factory,
  ILp__factory,
  KinkFeeModel__factory,
  POWAA__factory,
  UniswapV2GovLPVaultMigrator__factory,
} from "../../typechain";
import {
  assertEnvHOF,
  ETH_NETWORK,
  getAddress,
  getEqAssertionObj,
  IEnv,
  WEI_PER_ETHER,
} from "../utils";

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  // POWAA Token Params
  const powaaTokenParams = {
    totalSupply: parseEther("100000000000000"),
  };
  // Linear Fee Model
  const kinkFeeModelParams = {
    baseRate: parseEther("0.0009"),
    multiplierRate: parseEther("0.004"), // 0.4% of deposits
    jumpRate: parseEther("0.045"),
    kink: parseEther("0.6666666667"), // 66.7% utilization and kink will start
  };
  // POWAA-ETH UniswapV2 Pool
  const WETH9 = getAddress("WETH9", LAYER_NETWORK, env);
  // GovLPVault Migrator
  const govLPVaultMigratorParams = {
    router: getAddress("sushiswap_router", LAYER_NETWORK, env),
  };
  // GovLPVault Migration Options
  const govLPVaultRewardOptionParams = {
    rewardDuration: 691200, // 8 days
  };

  const POWAA = POWAA__factory.connect(
    getAddress("POWAA", LAYER_NETWORK, env),
    deployer
  );
  const KinkFeeModel = KinkFeeModel__factory.connect(
    getAddress("kink_fee_model", LAYER_NETWORK, env),
    deployer
  );
  const Controller = Controller__factory.connect(
    getAddress("controller", LAYER_NETWORK, env),
    deployer
  );
  const POWAA_ETHUniswapV2LP = ILp__factory.connect(
    getAddress("POWAA-ETH_sushiswap_lp", LAYER_NETWORK, env),
    deployer
  );
  const GovLPVaultMigrator = UniswapV2GovLPVaultMigrator__factory.connect(
    getAddress("gov_lp_vault_migrator", LAYER_NETWORK, env),
    deployer
  );
  const GovLPVault = GovLPVault__factory.connect(
    getAddress("gov_lp_vault", LAYER_NETWORK, env),
    deployer
  );

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
  console.log(">> Validate POWAA Deployment Params");
  console.table({
    totalSupply: getEqAssertionObj(
      powaaTokenParams.totalSupply.toString(),
      (await POWAA.totalSupply()).toString()
    ),
  });

  console.log(">> Validate Kink Fee Model Deployment Params");
  console.table({
    baseRate: getEqAssertionObj(
      kinkFeeModelParams.baseRate.toString(),
      (await KinkFeeModel.baseRate()).toString()
    ),
    multiplierRate: getEqAssertionObj(
      kinkFeeModelParams.multiplierRate
        .mul(WEI_PER_ETHER)
        .div(kinkFeeModelParams.kink)
        .toString(),
      (await KinkFeeModel.multiplierRate()).toString()
    ),
    kink: getEqAssertionObj(
      kinkFeeModelParams.kink.toString(),
      (await KinkFeeModel.kink()).toString()
    ),
    jumpRate: getEqAssertionObj(
      kinkFeeModelParams.jumpRate.toString(),
      (await KinkFeeModel.jumpRate()).toString()
    ),
  });

  console.log(">> Validate Controller's GovLpVault");
  console.table({
    govLPVault: getEqAssertionObj(
      await Controller.govLPVault(),
      GovLPVault.address
    ),
    registeredVaults: getEqAssertionObj(
      await Controller.registeredVaults(GovLPVault.address),
      true
    ),
  });

  console.log(">> Validate GovLPVault Params");
  console.table({
    masterContract: getEqAssertionObj(
      await GovLPVault.masterContract(),
      getAddress("gov_lp_vault_impl", LAYER_NETWORK, env)
    ),
    WETH9: getEqAssertionObj(await GovLPVault.WETH9(), WETH9),
    rewardsDistribution: getEqAssertionObj(
      await GovLPVault.rewardsDistribution(),
      await deployer.getAddress()
    ),
    rewardsToken: getEqAssertionObj(
      await GovLPVault.rewardsToken(),
      POWAA.address
    ),
    stakingToken: getEqAssertionObj(
      await GovLPVault.stakingToken(),
      POWAA_ETHUniswapV2LP.address
    ),
    rewardRate: getEqAssertionObj(
      (await GovLPVault.rewardRate()).toString(),
      "0"
    ),
    rewardsDuration: getEqAssertionObj(
      (await GovLPVault.rewardsDuration()).toNumber(),
      govLPVaultRewardOptionParams.rewardDuration
    ),
    isGovLpVault: getEqAssertionObj(await GovLPVault.isGovLpVault(), true),
    isMigrated: getEqAssertionObj(await GovLPVault.isMigrated(), false),
    reserve: getEqAssertionObj((await GovLPVault.reserve()).toString(), "0"),
    migrator: getEqAssertionObj(
      await GovLPVault.migrator(),
      GovLPVaultMigrator.address
    ),
    controller: getEqAssertionObj(
      await GovLPVault.controller(),
      Controller.address
    ),
  });
  console.log(`periodFinish: ${await GovLPVault.periodFinish()}`);

  console.log(">> Validate GovLpVault Migrators Params");
  console.table({
    router: getEqAssertionObj(
      await GovLPVaultMigrator.router(),
      govLPVaultMigratorParams.router
    ),
  });

  console.log(">> ✅ ALL PASS!");
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
