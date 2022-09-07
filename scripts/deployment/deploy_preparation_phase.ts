/* eslint-disable no-console */
import { parseEther } from "ethers/lib/utils";
import hre from "hardhat";
import {
  Controller__factory,
  GovLPVault__factory,
  IUniswapV2Factory__factory,
  KinkFeeModel__factory,
  POWAA__factory,
  TokenVault__factory,
  UniswapV2GovLPVaultMigrator__factory,
} from "../../typechain";
import { assertEnvHOF, ETH_NETWORK, getAddress, IEnv, save } from "../utils";

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();
  const BLOCK_NUMBER = await deployer?.provider?.getBlockNumber();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  // POWAA Token Params
  const powaaTokenParams = {
    totalSupply: parseEther("100000000000000"), // 100,000,000,000,000
  };
  // Kink Fee Model
  const kinkFeeModelParams = {
    baseRate: parseEther("0.0009"),
    multiplierRate: parseEther("0.004"), // 0.4% of deposits
    jumpRate: parseEther("0.045"),
    kink: parseEther("0.6666666667"), // 66.7% utilization and kink will start
  };
  // POWAA-ETH SushiSwap Pool
  const sushiswapFactory = getAddress("sushiswap_factory", LAYER_NETWORK, env);
  const WETH9 = getAddress("WETH9", LAYER_NETWORK, env);
  // GovLPVault Migrator
  const govLPVaultMigratorParams = {
    router: getAddress("sushiswap_router", LAYER_NETWORK, env),
    quoter: getAddress("uniswap_v3_quoter", LAYER_NETWORK, env),
  };
  // GovLPVault Migration Options
  const govLPVaultRewardOptionParams = {
    rewardDuration: 691200, // 8 days
  };

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  // 1) Deploy POWAA Token
  console.log(">> 1. Deploying POWAA Token...");
  const POWAA = await new POWAA__factory(deployer).deploy(
    powaaTokenParams.totalSupply
  );
  await POWAA.deployed();
  const mintTx = await POWAA.mint(
    deployer.address,
    powaaTokenParams.totalSupply
  );
  await mintTx.wait();
  save("POWAA", POWAA, LAYER_NETWORK, env, BLOCK_NUMBER);
  console.log(
    `>> ✅  Done Deploying POWAA Token with address ${POWAA.address} and mint tx : ${mintTx.hash}`
  );

  // 2) Deploy KinkFeeModel
  console.log(">> 2. Deploying KinkFeeModel...");
  const KinkFeeModel = await new KinkFeeModel__factory(deployer).deploy(
    kinkFeeModelParams.baseRate,
    kinkFeeModelParams.multiplierRate,
    kinkFeeModelParams.jumpRate,
    kinkFeeModelParams.kink
  );
  await KinkFeeModel.deployed();
  save("kink_fee_model", KinkFeeModel, LAYER_NETWORK, env, BLOCK_NUMBER);
  console.log(
    `>> ✅  Done Deploying KinkFeeModel Token with address ${KinkFeeModel.address}`
  );

  // 3) Deploy Controller
  console.log(">> 3. Deploying Controller...");
  const Controller = await new Controller__factory(deployer).deploy();
  await Controller.deployed();
  save("controller", Controller, LAYER_NETWORK, env, BLOCK_NUMBER);
  console.log(
    `>> ✅  Done Deploying Controller Token with address ${Controller.address}`
  );

  // 4) Create POWAA-ETH Pool
  console.log(">> 4. Create POWAA-ETH LP...");
  const SushiswapFactory = IUniswapV2Factory__factory.connect(
    sushiswapFactory,
    deployer
  );
  const createPoolTX = await SushiswapFactory.createPair(POWAA.address, WETH9);
  await createPoolTX.wait();
  const powaaETHLPAddress = await SushiswapFactory.getPair(
    POWAA.address,
    WETH9
  );
  save(
    "POWAA-ETH_sushiswap_lp",
    { address: powaaETHLPAddress },
    LAYER_NETWORK,
    env,
    BLOCK_NUMBER
  );
  console.log(
    `>> ✅ Done Create POWAA-ETH LP with tx: ${createPoolTX.hash} having an LP address of ${powaaETHLPAddress}`
  );

  // 5) Deploy TokenVault IMPL Contract
  console.log(">> 5. Deploying TokenVault Implementation Contract...");
  const TokenVaultIMPL = await new TokenVault__factory(deployer).deploy();
  await TokenVaultIMPL.deployed();
  save("token_vault_impl", TokenVaultIMPL, LAYER_NETWORK, env, BLOCK_NUMBER);
  console.log(
    `>> ✅  Done Deploying TokenVault Implementation Contract with address ${TokenVaultIMPL.address}`
  );

  // 6) Deploy GovLPVault IMPL Contract
  console.log(">> 6. Deploying GovLPVault Implementation Contract...");
  const GovLPVaultIMPL = await new GovLPVault__factory(deployer).deploy();
  await GovLPVaultIMPL.deployed();
  save("gov_lp_vault_impl", GovLPVaultIMPL, LAYER_NETWORK, env, BLOCK_NUMBER);
  console.log(
    `>> ✅  Done Deploying GovLPVault Implementation Contract with address ${GovLPVaultIMPL.address}`
  );

  // 7) Deploy GovLPVault Migrator
  console.log(">> 7. Deploying GovLPVault Migrator Contract...");
  const GovLPVaultMigrator = await new UniswapV2GovLPVaultMigrator__factory(
    deployer
  ).deploy(govLPVaultMigratorParams.router, govLPVaultMigratorParams.quoter);
  await GovLPVaultMigrator.deployed();
  save(
    "gov_lp_vault_migrator",
    GovLPVaultMigrator,
    LAYER_NETWORK,
    env,
    BLOCK_NUMBER
  );
  console.log(
    `>> ✅  Done Deploying GovLPVault Migrator Contract with address ${GovLPVaultMigrator.address}`
  );

  // 8) Deploy GovLPVault
  console.log(">> 8. Deploying GovLPVault Contract...");
  const govLpVaultAddress = await Controller.getDeterministicVault(
    GovLPVaultIMPL.address,
    powaaETHLPAddress
  );
  save(
    "gov_lp_vault",
    { address: govLpVaultAddress },
    LAYER_NETWORK,
    env,
    BLOCK_NUMBER
  );
  const deployGovLPVaultTx = await Controller.deployDeterministicVault(
    GovLPVaultIMPL.address,
    await deployer.getAddress(),
    POWAA.address,
    powaaETHLPAddress
  );
  await deployGovLPVaultTx.wait();
  console.log(
    `>> ✅  Done Deploying GovLPVault Contract with tx: ${deployGovLPVaultTx.hash} with address ${govLpVaultAddress}`
  );

  // 9) Set Migration Option for GovLPVault
  console.log(">> 9. Set GovLPVault Migration Option");
  const setGovLPVaultMigrationOptionTx = await GovLPVault__factory.connect(
    govLpVaultAddress,
    deployer
  ).setMigrationOption(GovLPVaultMigrator.address);
  await setGovLPVaultMigrationOptionTx.wait();
  console.log(
    `>> ✅  Done Set GovLPVault Migration Option with tx: ${setGovLPVaultMigrationOptionTx.hash}`
  );

  // 10) Whitelist GovLPVault as a caller to GovLPVault Migrator
  console.log(">> 10. Whitelist GovLPVault to GovLPVaultMigrator");
  const migratorWhitelistTokenVaultTx =
    await GovLPVaultMigrator.whitelistTokenVault(govLpVaultAddress, true);
  await migratorWhitelistTokenVaultTx.wait();
  console.log(
    `>> ✅  Whitelist GovLPVault to GovLPVaultMigrator with tx: ${migratorWhitelistTokenVaultTx.hash}`
  );

  // 11) Set setRewardsDuration to be aligned with the MERGE time in unix timestamp
  console.log(
    ">> 11. Set setRewardsDuration to be aligned with the MERGE time in unix timestamp"
  );
  const setRewardsDurationTx = await TokenVault__factory.connect(
    govLpVaultAddress,
    deployer
  ).setRewardsDuration(govLPVaultRewardOptionParams.rewardDuration);
  await setRewardsDurationTx.wait();
  console.log(
    `>> ✅  Done Set setRewardsDuration to be aligned with the MERGE time in unix timestamp with tx: ${setRewardsDurationTx.hash}`
  );
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
