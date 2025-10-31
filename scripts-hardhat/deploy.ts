import { ethers } from "hardhat";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with:", deployer.address);

    const Bitsave = await ethers.getContractFactory("Bitsave");
    const bitsave = await Bitsave.deploy(ZERO_ADDRESS, ZERO_ADDRESS);
    const tx = await bitsave.waitForDeployment();

    console.log("Bitsave deployed to:", await bitsave.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
