// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { ERC6551Registry } from "@erc6551/ERC6551Registry.sol";

import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";

import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { MockModule } from "test/foundry/mocks/MockModule.sol";
import { Governance } from "contracts/governance/Governance.sol";

contract ModuleRegistryTest is Test {
    IPAccountRegistry public registry;
    IPAccountImpl public implementation;
    ModuleRegistry public moduleRegistry;
    ERC6551Registry public erc6551Registry = new ERC6551Registry();
    MockAccessController public accessController = new MockAccessController();
    MockModule public module;
    Governance public governance;

    function setUp() public {
        governance = new Governance(address(this));
        moduleRegistry = new ModuleRegistry(address(governance));
        implementation = new IPAccountImpl();
        registry = new IPAccountRegistry(address(erc6551Registry), address(accessController), address(implementation));
        module = new MockModule(address(registry), address(moduleRegistry), "MockModule");
    }

    function test_ModuleRegistry_registerModule() public {
        moduleRegistry.registerModule("MockModule", address(module));
        assertEq(moduleRegistry.getModule("MockModule"), address(module));
        assertTrue(moduleRegistry.isRegistered(address(module)));
    }

    function test_ModuleRegistry_revert_registerModule_moduleAddressIsZero() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleAddressZeroAddress.selector));
        moduleRegistry.registerModule("MockModule", address(0));
    }

    function test_ModuleRegistry_revert_registerModule_moduleAddressIsNotContract() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleAddressNotContract.selector));
        moduleRegistry.registerModule("MockModule", address(0xbeefbeef));
    }

    function test_ModuleRegistry_revert_registerModule_moduleAlreadyRegistered() public {
        moduleRegistry.registerModule("MockModule", address(module));
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleAlreadyRegistered.selector));
        moduleRegistry.registerModule("MockModule", address(module));
    }

    function test_ModuleRegistry_revert_registerModule_nameEmptyString() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameEmptyString.selector));
        moduleRegistry.registerModule("", address(module));
    }

    function test_ModuleRegistry_revert_registerModule_nameAlreadyRegistered() public {
        moduleRegistry.registerModule("MockModule", address(module));
        MockModule newModule = new MockModule(address(registry), address(moduleRegistry), "NewMockModule");
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameAlreadyRegistered.selector));
        moduleRegistry.registerModule("MockModule", address(newModule));
    }

    function test_ModuleRegistry_revert_registerModule_nameDoesNotMatch() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameDoesNotMatch.selector));
        moduleRegistry.registerModule("WrongMockModuleName", address(module));
    }

    function test_ModuleRegistry_removeModule() public {
        moduleRegistry.registerModule("MockModule", address(module));
        assertEq(moduleRegistry.getModule("MockModule"), address(module));
        assertTrue(moduleRegistry.isRegistered(address(module)));
        moduleRegistry.removeModule("MockModule");
        assertEq(moduleRegistry.getModule("MockModule"), address(0));
        assertFalse(moduleRegistry.isRegistered(address(module)));
    }

    function test_ModuleRegistry_revert_removeModule_nameEmptyString() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__NameEmptyString.selector));
        moduleRegistry.removeModule("");
    }

    function test_ModuleRegistry_revert_removeModule_moduleNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.ModuleRegistry__ModuleNotRegistered.selector));
        moduleRegistry.removeModule("MockModuleMockMock");
    }
}
