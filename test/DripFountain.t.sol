// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Bitsave} from "../src/Bitsave.sol";
import {USDX} from "./USDX.sol";
import {BitsaveConfigs} from "../src/Config.sol";

contract DripFountainTest is Test, BitsaveConfigs {
    Bitsave public bitsave;
    address randomToken;

    // allow test contract to receive Ether
    receive() external payable {}

    function setUp() public {
        // Bitsave constructor sets masterAddress to msg.sender (this test contract)
        bitsave = new Bitsave(stableCoin, csToken);
        randomToken = address(new USDX());
    }

    function test_DripFountainNativeTransfersEtherToMaster() public {
        // fund the Bitsave contract with 5 ether
        uint256 fundAmount = 5 ether;
        vm.deal(address(bitsave), fundAmount);

        // record test contract balance before drip
        uint256 before = address(this).balance;

        // call dripFountain for native token (address(0)) as master
        bitsave.dripFountain(address(0));

        // after, test contract (master) should have increased by fundAmount
        uint256 afterBal = address(this).balance;
        assertEq(afterBal - before, fundAmount);
    }

    function test_DripFountainERC20TransfersTokenToMaster() public {
        // seed the Bitsave contract with ERC20 tokens
        uint256 tokenAmount = 100e18;
        deal(randomToken, address(bitsave), tokenAmount);

        // record test contract token balance before drip
        uint256 beforeBal = USDX(randomToken).balanceOf(address(this));

        // call dripFountain for ERC20 token as master
        bitsave.dripFountain(randomToken);

        // after, test contract (master) should have increased by tokenAmount
        uint256 afterBal = USDX(randomToken).balanceOf(address(this));
        assertEq(afterBal - beforeBal, tokenAmount);
    }
}
