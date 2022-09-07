/* eslint-disable no-console */
import { BigNumber } from "ethers";
import hre, { ethers } from "hardhat";
import { POWAA__factory, TokenVault__factory } from "../../typechain";
import {
  assertEnvHOF,
  ETH_NETWORK,
  getAddress,
  getEqAssertionObj,
  IEnv,
} from "../utils";

interface IVaultRewardAddress {
  vault: string;
  reward: BigNumber;
}

export async function main(): Promise<void> {
  const NETWORK = hre.network.name;
  const env = process.env.DEPLOYMENT_ENV as IEnv;

  const LAYER_NETWORK = `${NETWORK}/${ETH_NETWORK}`;

  const [deployer] = await hre.ethers.getSigners();

  // =-=-=-=-=-=- REVIEW VARIABLES CAREFULLY =-=-=-=-=-=-
  const vaultRewardAddresses: Array<IVaultRewardAddress> = [
    {
      vault: getAddress("gov_lp_vault", LAYER_NETWORK, env),
      reward: ethers.utils.parseEther("6000000000000"), // 6,000,000,000,000.00
    },
  ];
  const powaaAddress = getAddress("POWAA", LAYER_NETWORK, env);
  const gasPrice = ethers.utils.parseUnits("15", "gwei");

  // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

  for (let i = 0; i < vaultRewardAddresses.length; i++) {
    const tokenVaultAddress = vaultRewardAddresses[i].vault;
    const rewardAmount = vaultRewardAddresses[i].reward;
    console.log(
      `${i} Vault:  ${
        vaultRewardAddresses[i].vault
      } - reward: ${vaultRewardAddresses[i].reward.toString()}`
    );
    // 1) TokenVault Notify reward amount based on rewardsDuration * rewardPerSec
    console.log(`>> 1. Notify reward amount ${rewardAmount.toString()}`);
    const TokenVault = TokenVault__factory.connect(tokenVaultAddress, deployer);
    console.log(
      `>> 1.1 Transfer reward amount ${rewardAmount.toString()} to ${tokenVaultAddress}`
    );
    const transferTX = await POWAA__factory.connect(
      powaaAddress,
      deployer
    ).transfer(tokenVaultAddress, rewardAmount, {
      gasPrice,
    });
    await transferTX.wait();
    console.log(
      `>> 1.1 ✅ Done Transfer reward amount ${rewardAmount.toString()} to ${tokenVaultAddress}`
    );
    const notifyRewardAmountTx = await TokenVault.notifyRewardAmount(
      rewardAmount,
      {
        gasPrice,
      }
    );
    await notifyRewardAmountTx.wait();
    console.log(
      `>> ✅ Done Notify reward amount ${rewardAmount.toString()} with transfer tx: ${
        transferTX.hash
      } and notify tx: ${notifyRewardAmountTx.hash}`
    );

    // 2) Validations
    console.log(">> Validate TokenVault Params");
    console.table({
      rewardRate: getEqAssertionObj(
        (await TokenVault.rewardRate()).toString(),
        rewardAmount.div(await TokenVault.rewardsDuration()).toString()
      ),
    });
    if (!(await TokenVault.isGovLpVault())) {
      console.log(
        `campaign start block: ${(
          await TokenVault.campaignStartBlock()
        ).toString()}`
      );
    }
    console.log(`periodFinish: ${await TokenVault.periodFinish()}`);
  }
}

assertEnvHOF(process.env.DEPLOYMENT_ENV, "prod", main)
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
