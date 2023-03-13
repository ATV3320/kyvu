// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Cheatcodes.sol";

contract CheatcodesTest is Test {
    Cheatcodes public cheat;

    function setUp()public {
        cheat = new Cheatcodes();
    }

    function testFailedExample() public {
        cheat.setNumber(10);
        // assertEq()
        //since it is named 'testFail', it will pass when failed.
    }

    function testSuccessfulSetNumber() public {
        vm.warp(11);
        cheat.setNumber(14);
    }
}