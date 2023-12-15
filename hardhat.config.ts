import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

require("dotenv").config();

const {
  PRIVATE_KEY1,
  PRIVATE_KEY2,
  GOERLI_API_URL,
  SEPOLIA_API_URL,
  ETHEREUM_API_URL,
  ANDROMEDA_API_URL,
  HOLESKY_API_URL,
} = process.env;

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    sepolia: {
      url: SEPOLIA_API_URL,
      accounts: [PRIVATE_KEY1!, PRIVATE_KEY2!],
    },
    goerli: {
      url: GOERLI_API_URL,
      accounts: [PRIVATE_KEY1!, PRIVATE_KEY2!],
    },
    ethereum: {
      url: ETHEREUM_API_URL,
      accounts: [PRIVATE_KEY1!, PRIVATE_KEY2!],
    },
    andromeda: {
      url: ANDROMEDA_API_URL,
      accounts: [PRIVATE_KEY1!, PRIVATE_KEY2!],
    },
    holesky: {
      url: HOLESKY_API_URL,
      accounts: [PRIVATE_KEY1!, PRIVATE_KEY2!],
    },
  },
};

export default config;
