#!/usr/bin/env node
import { ethers } from "hardhat";

/**
 * resetFees.ts
 *
 * Usage (env vars):
 *   CONTRACT_ADDRESS=0x... JOIN_FEE=0 SAVING_FEE=0.0001 CHILD_CUT=50 npx hardhat run scripts/resetFees.ts --network <network>
 *
 * Usage (positional args):
 *   npx hardhat run scripts/resetFees.ts --network <network> <CONTRACT_ADDRESS> [<JOIN_FEE> <SAVING_FEE> <CHILD_CUT>]
 *
 * Assumption: "reset the fees" means restore the contract to the initial/default values used in the constructor:
 *   JoinLimitFee = 0
 *   SavingFee = 0.0001 ether
 *   ChildCutPerFee = 50
 *
 * The caller must be the `masterAddress` (owner) of the contract, otherwise the call will revert with
 * BitsaveHelperLib.MasterCallRequired().
 */

async function main() {
    const [signer] = await ethers.getSigners();

    // Read contract address from positional arg or env
    const positionalAddr = process.argv[2];
    const contractAddress = positionalAddr || process.env.CONTRACT_ADDRESS;
    if (!contractAddress) {
        throw new Error(
            "Provide contract address as first positional arg or CONTRACT_ADDRESS env var"
        );
    }

    // Defaults (assumption: restore initial values)
    const defaultJoinFee = BigInt(0);
    const defaultSavingFee = ethers.parseEther("0.0001");
    const defaultChildCut = 50;

    // allow overrides via positional args or env vars
    // positional args: [script, <contractAddress>, <joinFee>, <savingFee>, <childCut>]
    const joinFeeArg = process.argv[3] || process.env.JOIN_FEE;
    const savingFeeArg = process.argv[4] || process.env.SAVING_FEE;
    const childCutArg = process.argv[5] || process.env.CHILD_CUT;

    const joinFee = joinFeeArg ? BigInt(joinFeeArg) : defaultJoinFee;

    let savingFee: bigint;
    if (savingFeeArg) {
        // support ether format like "0.0001" or raw wei integer string
        if (savingFeeArg.includes(".")) {
            savingFee = ethers.parseEther(savingFeeArg);
        } else {
            savingFee = BigInt(savingFeeArg);
        }
    } else {
        savingFee = defaultSavingFee;
    }

    const childCut = childCutArg ? Number(childCutArg) : defaultChildCut;

    console.log("Signer:", signer.address);
    console.log("Target Bitsave contract:", contractAddress);
    console.log("Using values -> joinFee:", joinFee.toString(), "savingFee:", savingFee.toString(), "childCut:", childCut);

    const bitsave = await ethers.getContractAt("Bitsave", contractAddress, signer);

    const tx = await bitsave.editFees(joinFee, savingFee, childCut);
    console.log("tx hash:", tx.hash);
    const receipt = await tx.wait();
    if (receipt) {
        console.log("tx mined in block", receipt.blockNumber);
    } else {
        console.log("tx confirmed (no receipt returned)");
    }
    console.log("Fees updated successfully");
}

main()
    .then(() => process.exit(0))
    .catch((err) => {
        console.error(err);
        process.exit(1);
    });
