// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bitsave} from "../src/Bitsave.sol";
import {USDX} from "./USDX.sol";
import {ChildBitsave} from "../src/ChildContract.sol";

abstract contract BitsaveSetup {
    address stableCoin = address(0x05D032ac25d322df992303dCa074EE7392C117b9);
    address csToken = address(0x05D032ac25d322df992303dCa074EE7392C117b9);
    uint256 joinFee = 0.01 ether;

    // some users
    address userWJoined = address(1);
    address userNJoined = address(2);
    address userRandom = address(3);

    // struct saving data
    string school = "school";
    string erc20House = "erc20Hourse";
    uint savingAmount = 0.1 ether;
    uint extraTimeDuration = 1000;

}


contract BitsaveTest is Test, BitsaveSetup {
    Bitsave public bitsave;
    ChildBitsave public childBitsave;
    address randomToken;
    uint savedAmount;
    uint closeTime; 

    constructor() {
        bitsave = new Bitsave(stableCoin, csToken);
        randomToken = address(new USDX());
    }

    function setUp() public {
        vm.deal(userWJoined, 2 ether);
        vm.startPrank(userWJoined);
        bitsave.joinBitsave{value: joinFee}();
        ChildBitsave childContract = getChildContract();
        uint initialBalance = address(childContract).balance;
        closeTime = block.timestamp + extraTimeDuration;
        bitsave.createSaving{value: savingAmount}(school, closeTime, 1, false, address(0), savingAmount);
        uint finalBalance = address(childContract).balance;

        // check values
        ChildBitsave.SavingDataStruct memory saving = childContract.getSaving(school);
        assert(saving.isValid);
        savedAmount = finalBalance - initialBalance;
        assertEq(savedAmount, saving.amount);
        vm.stopPrank();
    }

    function getChildContract() internal returns (ChildBitsave childContract) {
        childContract = ChildBitsave(bitsave.getUserChildContractAddress());
    }

    function test_IncrementSaving() public {
        vm.startPrank(userWJoined);
        ChildBitsave childContract = getChildContract();
        uint initialBalance = address(childContract).balance;
        console.log("Init", initialBalance);
        uint closeTime = block.timestamp + extraTimeDuration;
        bitsave.incrementSaving{value: savingAmount}(school, address(0), savingAmount);
        uint finalBalance = address(childContract).balance;
        console.log("Final", finalBalance);

        // check values
        ChildBitsave.SavingDataStruct memory saving = childContract.getSaving(school);
        assert(saving.isValid);
        uint newSavingBalance = savingAmount;
        assertEq(finalBalance - initialBalance, newSavingBalance);
        vm.stopPrank();
    }


    function saveERC20(string memory savingName) internal {
        deal(randomToken, userWJoined, 130e18);
        ChildBitsave childContract = getChildContract();

        uint initialBalance = USDX(randomToken).balanceOf(userWJoined);
        uint closeTime = block.timestamp + extraTimeDuration;
        // allowance
        USDX(randomToken).approve(address(bitsave), savingAmount);
        // create saving with randomToken
        bitsave.createSaving{value: savingAmount}(savingName, closeTime, 1, false, randomToken, savingAmount);
        uint finalBalance = USDX(randomToken).balanceOf(userWJoined);
        savedAmount = initialBalance - finalBalance;
    }

}
