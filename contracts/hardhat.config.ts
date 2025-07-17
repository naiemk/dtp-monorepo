import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "dotenv/config";

// Import scripts to register tasks
import "./scripts/deploy";

console.log("ETHERSCAN_API_KEY", process.env.ETHERSCAN_API_KEY);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6",
  },
  networks: {
    hardhat: {
      chainId: 31337,
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
        count: 10,
      },
    },
    local: {
      url: "http://localhost:8545",
      chainId: 31337,
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
        count: 10,
      },
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/public",
      accounts: [process.env.PRIVATE_KEY || ''],
    },
  },
  ignition: {
    strategyConfig: {
      create2: {
        // To learn more about salts, see the CreateX documentation
        salt: "0x0000000000000000000000000000000000000000000000000000000000000000",
      },
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || '',
    // apiKey: {
    //   sepolia: process.env.ETHERSCAN_API_KEY || '',
    //   mainnet: process.env.ETHERSCAN_API_KEY || '',
    // },
  },
};

export default config;
