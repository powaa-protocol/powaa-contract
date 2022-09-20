import { ethers, PayableOverrides } from "ethers";
import { DEPLOYMENTS_DIR, IEnv } from ".";
import { Timelock } from "../../typechain";
import { PromiseOrValue } from "../../typechain/common";
import fs from "fs";

export interface ITimelockResponse {
  info: string;
  queuedAt: string;
  executedAt: string;
  executionTransaction: string;
  target: string;
  value: string;
  signature: string;
  paramTypes: Array<string>;
  params: Array<any>;
  eta: string;
}

export async function queueTransaction(
  instance: Timelock,
  info: string,
  target: string,
  value: string,
  signature: string,
  paramTypes: Array<string>,
  params: Array<any>,
  eta: string,
  overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
): Promise<ITimelockResponse> {
  console.log(`==========`);
  console.log(`>> Queue tx for: ${info}`);
  const queueTx = await instance.queueTransaction(
    target,
    value,
    signature,
    ethers.utils.defaultAbiCoder.encode(paramTypes, params),
    eta,
    { ...(!!overrides && { ...overrides }) }
  );

  await queueTx.wait();

  const executionTx = `await timelock.executeTransaction('${target}', '${value}', '${signature}', ethers.utils.defaultAbiCoder.encode(${JSON.stringify(
    paramTypes
  )}, ${JSON.stringify(params)}), '${eta}')`;
  console.log(`>> Done.`);
  return {
    info: info,
    queuedAt: queueTx.hash,
    executedAt: "",
    executionTransaction: executionTx,
    target,
    value,
    signature,
    paramTypes,
    params,
    eta,
  };
}

export async function executeTransaction(
  instance: Timelock,
  info: string,
  queuedAt: string,
  executionTx: string,
  target: string,
  value: string,
  signature: string,
  paramTypes: Array<string>,
  params: Array<any>,
  eta: string,
  overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
): Promise<ITimelockResponse> {
  console.log(`==========`);
  console.log(`>> Execute tx for: ${info}`);

  const estimatedGas = await instance.estimateGas.executeTransaction(
    target,
    value,
    signature,
    ethers.utils.defaultAbiCoder.encode(paramTypes, params),
    eta
  );

  const executeTx = await instance.executeTransaction(
    target,
    value,
    signature,
    ethers.utils.defaultAbiCoder.encode(paramTypes, params),
    eta,
    {
      ...(!!overrides && { ...overrides, gasLimit: estimatedGas.add(2000000) }),
    }
  );
  console.log(`>> Done.`);

  return {
    info: info,
    queuedAt: queuedAt,
    executedAt: executeTx.hash,
    executionTransaction: executionTx,
    target,
    value,
    signature,
    paramTypes,
    params,
    eta,
  };
}

export function saveJSON(
  name: string,
  content: any,
  network: string,
  env: IEnv
) {
  const timestamp = Math.floor(Date.now() / 1000);
  if (!fs.existsSync(`${DEPLOYMENTS_DIR}/${network}/${env}/json`)) {
    fs.mkdirSync(`${DEPLOYMENTS_DIR}/${network}/${env}/json`, {
      recursive: true,
    });
  }
  fs.writeFileSync(
    `${DEPLOYMENTS_DIR}/${network}/${env}/json/${timestamp}_${name}.json`,
    JSON.stringify(content, null, 2)
  );
}

export function getJSON<T>(name: string, network: string, env: IEnv): T {
  try {
    return JSON.parse(
      fs
        .readFileSync(`./deployments/${network}/${env}/json/${name}.json`)
        .toString()
    );
  } catch (err) {
    throw Error(`${name} deployment on ${network} not found`);
  }
}
