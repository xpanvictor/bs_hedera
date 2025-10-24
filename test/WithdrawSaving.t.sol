// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bitsave, BitsaveHelperLib} from "../src/Bitsave.sol";
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
        vm.deal(userWJoined, 1 ether);
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

    function test_WithdrawNativeSaving() public {

        vm.startPrank(userWJoined);
        uint initialBalance = userWJoined.balance;

        ChildBitsave childContract = getChildContract();
        vm.warp(closeTime);
        bitsave.withdrawSaving(school);
        uint finalBalance = userWJoined.balance;

        assertEq(finalBalance - initialBalance, savedAmount);
        vm.stopPrank();
    }

    function test_RevertIf_InvalidSaving() public {

        vm.startPrank(userWJoined);
        uint initialBalance = userWJoined.balance;

        ChildBitsave childContract = getChildContract();
        vm.warp(closeTime);
        bitsave.withdrawSaving(school);
        uint finalBalance = userWJoined.balance;

        assertEq(finalBalance - initialBalance, savedAmount);

        vm.expectPartialRevert(BitsaveHelperLib.InvalidSaving.selector);
        bitsave.withdrawSaving(school);
        vm.stopPrank();
    }

    function test_WithdrawNativeSavingTakesOnlySaving() public {

        vm.startPrank(userWJoined);

        ChildBitsave childContract = getChildContract();
        uint initialContractBalance = address(childContract).balance;
        vm.warp(closeTime);
        bitsave.withdrawSaving(school);
        uint finalContractBalance = address(childContract).balance;

        assertEq(initialContractBalance - finalContractBalance, savedAmount);
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

     function test_WithdrawERC20Saving() public {

        vm.startPrank(userWJoined);
        saveERC20(erc20House);

        //  withdraw
        uint initialBalance = USDX(randomToken).balanceOf(userWJoined);

        ChildBitsave childContract = getChildContract();
        vm.warp(closeTime);
        bitsave.withdrawSaving(erc20House);
        uint finalBalance = USDX(randomToken).balanceOf(userWJoined);

        assertEq(finalBalance - initialBalance, savedAmount);
        vm.stopPrank();
    }

}
