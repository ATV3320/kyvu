pragma solidity 0.8.13;

import "forge-std/Test.sol";
import "../src/mirror.sol";

contract mirrorTest is Test {
    Mirror public mirror;
    function setUp() public {
        mirror = new Mirror();
    }

    function testNonEdgeCase() public {
        assertEq(mirror.mirror(25), 25);
    }
    function testEdgeCase() public {
        assertEq(mirror.mirror(50),1);
    }

    // function testFuzz(uint256 x) public {
    //     assertEq(mirror.mirror(x),x);
    // }
}