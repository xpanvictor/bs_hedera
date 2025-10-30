#!/usr/bin/env node
import hre from "hardhat";
import { ethers } from "hardhat";

/**
 * verifyContract.ts
 *
 * Compares the on-chain runtime bytecode of a deployed contract with the locally
 * compiled artifact for `Bitsave`. This is a fast local verification check.
 *
 * Usage (env vars):
 *   CONTRACT_ADDRESS=0x... npx hardhat run --network hederaTestnet scripts/verifyContract.ts
 *
 * Usage (positional):
 *   npx hardhat run --network hederaTestnet scripts/verifyContract.ts -- 0x...
 *
 * Optional: to attempt a hardhat-verify run (requires @nomicfoundation/hardhat-verify plugin
 * and API keys configured for the chosen network), set RUN_HARDHAT_VERIFY=true in env.
 */

function stripHexPrefix(s: string) {
  return s.startsWith("0x") ? s.slice(2) : s;
}

function findMetadataIndex(hex: string): number {
  // Heuristic: look for common Solidity metadata prefixes used at the end of runtime bytecode
  const patterns = [
    "a165627a7a72305820", // swarm
    "a264697066735822", // ipfs
    "a2646970667358", // shorter ipfs variant
  ];
  const lower = hex.toLowerCase();
  for (const p of patterns) {
    const idx = lower.indexOf(p);
    if (idx !== -1) return idx;
  }
  return -1;
}

async function main() {
  const positional = process.argv[2];
  const contractAddress = positional || process.env.CONTRACT_ADDRESS;
  if (!contractAddress) {
    throw new Error("Provide contract address as positional arg or CONTRACT_ADDRESS env var");
  }

  console.log("Using network:", hre.network.name);
  console.log("Checking contract:", contractAddress);

  const artifact = await hre.artifacts.readArtifact("Bitsave");
  const localRuntime = stripHexPrefix(artifact.deployedBytecode);

  const onchainRaw = await ethers.provider.getCode(contractAddress);
  const onchain = stripHexPrefix(onchainRaw);

  if (!onchain || onchain === "" || onchain === "0") {
    console.error("No contract found at the provided address (empty bytecode). Is the address correct and the network the right one?");
    process.exit(2);
  }

  console.log(`Local runtime bytecode length: ${localRuntime.length / 2} bytes`);
  console.log(`On-chain runtime bytecode length: ${onchain.length / 2} bytes`);

  if (onchain === localRuntime) {
    console.log("✅ Exact match: on-chain runtime bytecode equals compiled artifact runtime bytecode.");
  } else {
    // try stripping metadata heuristically from local artifact
    const metaIdx = findMetadataIndex(localRuntime);
    if (metaIdx !== -1) {
      const strippedLocal = localRuntime.slice(0, metaIdx);
      if (onchain === strippedLocal) {
        console.log("✅ Match after stripping local metadata. The metadata appended by the compiler differs but runtime matches.");
        process.exit(0);
      }
      // also check if onchain contains stripped local as prefix
      if (onchain.startsWith(strippedLocal)) {
        console.log("⚠️ On-chain bytecode starts with compiled runtime bytecode (local metadata may differ).");
        process.exit(0);
      }
    }

    // fallback: check if local runtime is a prefix of onchain (or vice-versa)
    if (onchain.startsWith(localRuntime)) {
      console.log("⚠️ On-chain bytecode starts with local runtime bytecode (on-chain has extra data at the end).");
    } else if (localRuntime.startsWith(onchain)) {
      console.log("⚠️ Local runtime bytecode starts with on-chain bytecode (on-chain truncated or different compiler settings).");
    } else {
      console.error("❌ Bytecode mismatch — on-chain runtime bytecode does not match the locally compiled runtime bytecode.");
      console.error("Possible causes: different compiler version/settings, different source or constructor args/immutables, linked libraries, or metadata differences.");
      console.error("Hints:");
      console.error(" - Confirm you compiled with the same Solidity version and optimizer settings used for deployment.");
      console.error(" - If you used constructor args or library linking, provide them when verifying on explorers.");
      console.error(" - Try running Hardhat's verify task if the network explorer supports it and you have API keys configured.");
    }
  }

  // Optional: try running hardhat verify task if requested
  if (process.env.RUN_HARDHAT_VERIFY === "true") {
    console.log("Attempting to run hardhat verify:verify task (requires plugin + explorer API key)...");
    try {
      // empty constructor args by default; change if needed
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: [],
      });
      console.log("Hardhat verify task completed (see plugin output). If it succeeded, the contract is verified on the explorer.");
    } catch (err: any) {
      console.error("Hardhat verify failed:", err.message ?? err);
      console.error("Ensure @nomicfoundation/hardhat-verify is installed and configured with API keys for the network.");
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
