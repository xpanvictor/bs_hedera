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
    uint savingAmount = 0.1 ether;
    uint extraTimeDuration = 1000;

}


contract BitsaveTest is Test, BitsaveSetup {
    Bitsave public bitsave;
    ChildBitsave public childBitsave;
    address randomToken;

    constructor() {
        bitsave = new Bitsave(stableCoin, csToken);
        randomToken = address(new USDX());
    }

    function setUp() public {
        vm.deal(userWJoined, 1 ether);
        vm.prank(userWJoined);
        bitsave.joinBitsave{value: joinFee}();
    }

    function getChildContract() internal returns (ChildBitsave childContract) {
        childContract = ChildBitsave(bitsave.getUserChildContractAddress());
    }

    function test_CreateSavingWithNative() public {
        vm.startPrank(userWJoined);
        ChildBitsave childContract = getChildContract();
        uint initialBalance = address(childContract).balance;
        uint closeTime = block.timestamp + extraTimeDuration;
        bitsave.createSaving{value: savingAmount}(school, closeTime, 1, false, address(0), savingAmount);
        uint finalBalance = address(childContract).balance;

        // check values
        ChildBitsave.SavingDataStruct memory saving = childContract.getSaving(school);
        assert(saving.isValid);
        assertEq(finalBalance - initialBalance, saving.amount);
        vm.stopPrank();
    }

    function testFail_NoAllowance() public {
        vm.expectRevert();
        vm.startPrank(userWJoined);
        deal(randomToken, userWJoined, 130e18);
        ChildBitsave childContract = getChildContract();

        uint initialBalance = USDX(randomToken).balanceOf(userWJoined);
        uint closeTime = block.timestamp + extraTimeDuration;
        // create saving with randomToken
        bitsave.createSaving{value: savingAmount}(school, closeTime, 1, false, randomToken, savingAmount);
        
        vm.stopPrank();
    }

    function test_CreateSavingWithERC20() public {
        vm.startPrank(userWJoined);
        deal(randomToken, userWJoined, 130e18);
        ChildBitsave childContract = getChildContract();

        uint initialBalance = USDX(randomToken).balanceOf(userWJoined);
        uint closeTime = block.timestamp + extraTimeDuration;
        // allowance
        USDX(randomToken).approve(address(bitsave), savingAmount);
        // create saving with randomToken
        bitsave.createSaving{value: savingAmount}(school, closeTime, 1, false, randomToken, savingAmount);
        uint finalBalance = USDX(randomToken).balanceOf(userWJoined);

        console.log(initialBalance);

        // check values
        ChildBitsave.SavingDataStruct memory saving = childContract.getSaving(school);
        assert(saving.isValid);
        assertEq(initialBalance - finalBalance, saving.amount);

        vm.stopPrank();
    }

    function test_RevertIf_InvalidSaving() public {
        vm.startPrank(userWJoined);
        deal(randomToken, userWJoined, 130e18);
        uint closeTime = block.timestamp + extraTimeDuration;
        ChildBitsave childContract = getChildContract();

        // first saving
        bitsave.createSaving{value: savingAmount}(school, closeTime, 1, false, address(0), savingAmount);

        uint initialBalance = USDX(randomToken).balanceOf(userWJoined);
        // allowance
        USDX(randomToken).approve(address(bitsave), savingAmount);
        // create saving with randomToken
        vm.expectPartialRevert(BitsaveHelperLib.InvalidSaving.selector);
        bitsave.createSaving{value: savingAmount}(school, closeTime, 1, false, randomToken, savingAmount);
        vm.stopPrank();
    }
}