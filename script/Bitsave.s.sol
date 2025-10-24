// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Bitsave} from "../src/Bitsave.sol";
import {Create2} from "../src/Create2.sol";
import {BitsaveConfigs} from "../src/Config.sol";

contract BitsaveScript is Script, BitsaveConfigs {
    Bitsave public bitsave;
    Create2 create2;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // create2 = new Create2();

        // // Prepare the bytecode for MyContract
        // bytes memory bytecode = abi.encodePacked(
        //     type(Bitsave).creationCode,
        //     stableCoin,
        //     csToken
        // );

        // // Define a salt
        // bytes32 salt = keccak256(rawSalt);

        // // Deploy using CREATE2
        // address deployedAddr = create2.deploy(bytecode, salt);

        // console.log("Deployed Contract Address:", deployedAddr);

        bitsave = new Bitsave(stableCoin, csToken);

        vm.stopBroadcast();
    }
}
