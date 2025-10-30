// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Bitsave} from "../src/Bitsave.sol";
import {Create2} from "../src/Create2.sol";
import {BitsaveConfigs} from "../src/Config.sol";

contract BitsaveScript is Script, BitsaveConfigs {
    Bitsave public bitsave;
    Create2 create2;

    function run() external returns (address) {
        // Load the private key from the .env file
        uint256 deployerPrivateKey = vm.envUint("HEDERA_PRIVATE_KEY");

        // Start broadcasting transactions with the loaded private key
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the contract
        bitsave = new Bitsave(stableCoin, csToken);
        console.log("Bitsave Contract deployed to:", address(bitsave));

        // Stop broadcasting
        vm.stopBroadcast();

        console.log("Bitsave Contract deployed to:", address(bitsave));

        return address(bitsave);
    }
}
