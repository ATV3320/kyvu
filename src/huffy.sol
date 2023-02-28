// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

interface IReadWrite {
	function set(uint256) external;
	function get() external view returns (uint256);
}

contract ReadWriteTest is Test {

	address internal yul;
	address internal huff;

	function setUp() external {
		address _yul;
		address _huff;
		bytes memory yulCode = hex"6053600d60003960536000f3fe60056041565b6360fe47b18114601e57636d4ce63c8114602c57600080fd5b6004356027604d565b55603c565b6032604d565b5460005260206000f35b506052565b6000803560e01c905090565b600090565b";
		bytes memory huffCode = hex"61002e8061000d6000396000f360003560e01c80636d4ce63c1461001b576360fe47b114610027575b60005460005260206000f35b600435600055";
		bytes32 salt = keccak256(abi.encode(1));
		assembly {
			_yul := create2(0, add(yulCode, 32), mload(yulCode), salt)
			_huff := create2(0, add(huffCode, 32), mload(huffCode), salt)
		}
		yul = _yul;
		huff = _huff;
	}

	function testYulGet() external {
		uint256 gasBefore = gasleft();
		uint256 value = IReadWrite(yul).get();
		emit log_named_uint("yul.get()", gasBefore - gasleft());
		assertEq(value, 0);
	}

	function testYulSet() external {
		uint256 gasBefore = gasleft();
		IReadWrite(yul).set(1);
		emit log_named_uint("yul.set(uint256)", gasBefore - gasleft());
		uint256 value = IReadWrite(yul).get();
		assertEq(value, 1);
	}

	function testHuffGet() external {
		uint256 gasBefore = gasleft();
		uint256 value = IReadWrite(huff).get();
		emit log_named_uint("huff.get()", gasBefore - gasleft());
		assertEq(value, 0);
	}

	function testHuffSet() external {
		uint256 gasBefore = gasleft();
		IReadWrite(huff).set(1);
		emit log_named_uint("huff.set(uint256)", gasBefore - gasleft());
		uint256 value = IReadWrite(huff).get();
		assertEq(value, 1);
	}
}
