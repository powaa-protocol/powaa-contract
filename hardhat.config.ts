import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-upgrades";
import "@typechain/hardhat";
import "hardhat-log-remover";
import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
import "solidity-coverage";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const chainIds = {
  goerli: 5,
  hardhat: 31337,
  kovan: 42,
  mainnet: 1,
  rinkeby: 4,
  ropsten: 3,
};

const goerliTestnetPrivateKey: string | undefined =
  process.env.GOERLI_TESTNET_PRIVATE_KEY;
if (!goerliTestnetPrivateKey) {
  throw new Error("Please set your GOERLI_TESTNET_PRIVATE_KEY in a .env file");
}

const alchemyKey: string | undefined = process.env.ALCHEMY_KEY;
if (!alchemyKey) {
  throw new Error("Please set your ALCHEMY_KEY in a .env file");
}

const mainnetForkRPC: string | undefined = process.env.MAINNET_FORK_RPC_URL;
if (!mainnetForkRPC) {
  throw new Error("Please set your MAINNET_FORK_RPC_URL in a .env file");
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: chainIds.hardhat,
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      timeout: 1800000,
      accounts: [
        {
          privateKey: process.env.LOCAL_PRIVATE_KEY_1,
          balance: "10000000000000000000000",
        },
        {
          privateKey: process.env.LOCAL_PRIVATE_KEY_2,
          balance: "10000000000000000000000",
        },
        {
          privateKey: process.env.LOCAL_PRIVATE_KEY_3,
          balance: "10000000000000000000000",
        },
        {
          privateKey: process.env.LOCAL_PRIVATE_KEY_4,
          balance: "10000000000000000000000",
        },
      ],
    },
    goerli: {
      accounts: [goerliTestnetPrivateKey as string],
      chainId: chainIds["goerli"],
      url: `https://eth-goerli.g.alchemy.com/v2/${alchemyKey}`,
    },
    mainnetfork: {
      accounts: [goerliTestnetPrivateKey as string],
      chainId: chainIds["mainnet"],
      url: mainnetForkRPC,
    },
    devnet: {
      url: "http://localhost:5000",
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  solidity: {
    version: "0.8.14",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      evmVersion: "istanbul",
      outputSelection: {
        "*": {
          "": ["ast"],
          "*": [
            "evm.bytecode.object",
            "evm.deployedBytecode.object",
            "abi",
            "evm.bytecode.sourceMap",
            "evm.deployedBytecode.sourceMap",
            "metadata",
            "storageLayout",
          ],
        },
      },
    },
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  typechain: {
    outDir: "./typechain",
    target: process.env.TYPECHAIN_TARGET || "ethers-v5",
  },
  mocha: {
    timeout: 800000,
  },
};
