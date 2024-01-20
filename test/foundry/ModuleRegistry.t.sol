// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";

import "contracts/registries/IPAccountRegistry.sol";
import "contracts/IPAccountImpl.sol";
import "contracts/interfaces/IIPAccount.sol";

import "test/foundry/mocks/MockERC721.sol";
import "test/foundry/mocks/MockAccessController.sol";
import "test/foundry/mocks/MockModule.sol";
import "contracts/registries/ModuleRegistry.sol";
import "contracts/lib/Errors.sol";

contract ModuleRegistryTest is Test {
    IPAccountRegistry public registry;
    IPAccountImpl public implementation;
    ModuleRegistry public moduleRegistry = new ModuleRegistry();
    ERC6551Registry public erc6551Registry = new ERC6551Registry();
    MockAccessController public accessController = new MockAccessController();
    MockModule public module;

    function setUp() public {
        implementation = new IPAccountImpl();
        registry = new IPAccountRegistry(address(erc6551Registry), address(accessController), address(implementation));
        module = new MockModule(address(registry), address(moduleRegistry), "MockModule");
    }

    function test_ModuleRegistry_registerModule() public {
        moduleRegistry.registerModule("MockModule", address(module));
        assertEq(moduleRegistry.getModule("MockModule"), address(module));
        assertTrue(moduleRegistry.isRegistered(address(module)));
    }

    function test_ModuleRegistry_revert_registerModule_ifModuleAlreadyRegistered() public {
        moduleRegistry.registerModule("MockModule", address(module));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.ModuleRegistry__ModuleAlreadyRegistered.selector
            )
        );
        moduleRegistry.registerModule("MockModule", address(module));
    }

    function test_ModuleRegistry_removeModule() public {
        moduleRegistry.registerModule("MockModule", address(module));
        assertEq(moduleRegistry.getModule("MockModule"), address(module));
        assertTrue(moduleRegistry.isRegistered(address(module)));
        moduleRegistry.removeModule("MockModule");
        assertEq(moduleRegistry.getModule("MockModule"), address(0));
        assertFalse(moduleRegistry.isRegistered(address(module)));
    }

}
