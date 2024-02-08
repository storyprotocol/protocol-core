// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

/// @title Base Test Contract
/// @notice This contract provides a set of protocol-unrelated testing utilities
///         that may be extended by testing contracts.
contract BaseTest is Test {
    // Test public keys EOAs for deriving reusable EOA addresses.
    uint256 internal alicePk = 0xa11ce;
    uint256 internal bobPk = 0xb0b;
    uint256 internal calPk = 0xca1;

    // Test EOA addresses that may be reused for testing.
    address payable internal alice = payable(vm.addr(alicePk));
    address payable internal bob = payable(vm.addr(bobPk));
    address payable internal cal = payable(vm.addr(calPk));

    /// @notice Sets up the base test contract.
    function setUp() public virtual {
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(cal, "cal");
    }
}
