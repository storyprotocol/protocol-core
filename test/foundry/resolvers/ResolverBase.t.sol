// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";

import { ModuleBaseTest } from "test/foundry/modules/ModuleBase.t.sol";

/// @title Resolver Base Test Contract
/// @notice Base contract for testing standard resolver functionality.
abstract contract ResolverBaseTest is ModuleBaseTest {
    /// @notice The resolver SUT.
    IResolver public baseResolver;

    /// @notice Initializes the base ERC20 contract for testing.
    function setUp() public virtual override(ModuleBaseTest) {
        ModuleBaseTest.setUp();
        baseResolver = IResolver(_deployModule());
    }

    /// @notice Tests that the base resolver interface is supported.
    function test_Resolver_SupportsInterface() public virtual {
        assertTrue(baseResolver.supportsInterface(type(IResolver).interfaceId));
    }
}
