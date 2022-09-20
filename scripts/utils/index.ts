import { expect } from "chai";
import { ethers } from "ethers";
import fs from "fs";

export const DEPLOYMENTS_DIR = `deployments`;
export const MASK_250 = BigInt(2 ** 250 - 1);
export const WEI_PER_ETHER = BigInt(1_000_000_000_000_000_000);
export const ETH_NETWORK = "eth";

export type IEnv = "develop" | "prod";

export function isENV(env: string): env is IEnv {
  return env === "develop" || env === "prod";
}

/**
 * If the current environment is not the expected environment, throw an error
 * @param {string | undefined} actualEnv - The actual environment that the function is running in.
 * @param {IEnv} expectedEnv - The expected environment.
 * @param func - () => Promise<void>
 */
export async function assertEnvHOF(
  actualEnv: string | undefined,
  expectedEnv: IEnv,
  func: () => Promise<void>
): Promise<void> {
  if (process.env.DEPLOYMENT_ENV !== expectedEnv) {
    throw new Error(`expected ENV: ${expectedEnv}; actual ENV: ${actualEnv}`);
  }
  await func();
}

export function getAddress(
  contract: string,
  network: string,
  env: IEnv
): string {
  try {
    return JSON.parse(
      fs
        .readFileSync(`./deployments/${network}/${env}/${contract}.json`)
        .toString()
    ).address;
  } catch (err) {
    throw Error(
      `${contract} deployment on ${network} not found, run 'yarn deploy:${network}'`
    );
  }
}

export function getAccounts(network: string, env: IEnv): Array<string> {
  const files = fs.readdirSync(`./deployments/${network}/${env}`);
  return files
    .filter((file) => file.slice(0, 7) === "account")
    .map((file) => {
      return file.split("-")[1].split(".")[0];
    });
}

export function parseCalldataL1(
  calldata: string,
  network: string,
  env: IEnv
): Array<string> {
  const _calldata = calldata ? calldata.split(",") : [];
  const accounts = getAccounts(network, env);
  return _calldata.map((input: string) => {
    if (accounts.includes(input)) {
      return BigInt(getAddress(`account-${input}`, network, env)).toString();
    }
    return input;
  });
}

export function save(
  name: string,
  contract: any,
  network: string,
  env: IEnv,
  block?: number
): void {
  if (!fs.existsSync(`${DEPLOYMENTS_DIR}/${network}/${env}`)) {
    fs.mkdirSync(`${DEPLOYMENTS_DIR}/${network}/${env}`, { recursive: true });
  }
  fs.writeFileSync(
    `${DEPLOYMENTS_DIR}/${network}/${env}/${name}.json`,
    JSON.stringify({
      address: contract.address,
      block,
    })
  );
}

export function getSelectorFromName(name: string) {
  return (
    BigInt(ethers.utils.keccak256(Buffer.from(name))) % MASK_250
  ).toString();
}

export function getEqAssertionObj(
  expected: any,
  actual: any,
  delta?: any
): { expected: any; actual: any; result: boolean } {
  if (delta) {
    expect(expected).approximately(actual, delta);
  } else {
    if (typeof expected == "string") {
      expect(expected.toLowerCase()).to.eq(actual.toLowerCase());
    } else {
      expect(expected).to.eq(actual);
    }
  }

  return {
    expected,
    actual,
    result: expected === actual,
  };
}
