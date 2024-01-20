// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";

import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Resolver Base Test Contract
/// @notice Base contract for testing standard resolver functionality.
abstract contract ResolverBaseTest is BaseTest {

    /// @notice The access controller address.
    IAccessController public accessController;

    /// @notice The resolver SUT.
    IResolver public baseResolver;

    /// @notice Initializes the base ERC20 contract for testing.
    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();
        accessController = IAccessController(address(new MockAccessController()));
        baseResolver = IResolver(_deployResolver());
    }

    /// @notice Tests that the default resolver constructor runs successfully.
    function test_Resolver_Constructor() public {
        assertEq(baseResolver.accessController(), address(accessController));
    }

    /// @notice Tests that the base resolver interface is supported.
    function test_Resolver_SupportsInterface() public virtual {
        assertTrue(baseResolver.supportsInterface(type(IResolver).interfaceId));
    }

    /// @dev Deploys the resolver SUT.
    function _deployResolver() internal virtual returns (address);

}
