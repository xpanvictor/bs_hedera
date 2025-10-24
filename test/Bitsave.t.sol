// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bitsave, BitsaveHelperLib} from "../src/Bitsave.sol";
import {BitsaveConfigs} from "../src/Config.sol";
import {ChildBitsave} from "../src/ChildContract.sol";

contract BitsaveTest is Test, BitsaveConfigs {
    Bitsave public bitsave;
    ChildBitsave public childBitsave;

    constructor() {
        bitsave = new Bitsave(stableCoin, csToken);
        console.log(bitsave.masterAddress(), address(this));
    }

    function setUp() public {}

    function test_SetStableCoin() public {
        assertEq(address(bitsave.stableCoin()), stableCoin);
    }

    function test_SetCSToken() public {
        assertEq(address(bitsave.csToken()), csToken);
    }

    function test_SetMasterAddr() public {
        assertEq(address(bitsave.masterAddress()), address(this));
    }

    function test_RevertIf_JoinWithLowFee() public {
       vm.expectPartialRevert(BitsaveHelperLib.AmountNotEnough.selector);
       address newUser = address(1);
       vm.deal(newUser, 1 ether);
       vm.prank(newUser);
       bitsave.joinBitsave{value: 0.000000001 ether}();
    }

}
