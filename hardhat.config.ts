import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const HEDERA_TN_RPC_URL = process.env.HEDERA_TN_RPC_URL;
const HEDERA_PRIVATE_KEY = process.env.HEDERA_PRIVATE_KEY;

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  paths: {
    // project keeps Solidity sources in `src/` (not the default `contracts/`)
    sources: "src",
  },
  networks: {
    hederaTestnet: {
      url: HEDERA_TN_RPC_URL ?? "",
      // Expect private key to be set in .env as HEDERA_PRIVATE_KEY
      accounts: HEDERA_PRIVATE_KEY ? [HEDERA_PRIVATE_KEY] : [],
      // Hedera testnet EVM chain id used in this repo's broadcasts
      chainId: 296,
    },
  },
};

export default config;
