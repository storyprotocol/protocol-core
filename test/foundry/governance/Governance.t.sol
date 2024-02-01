// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Test } from "forge-std/Test.sol";

import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";

import { AccessController } from "contracts/AccessController.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { MockModule } from "test/foundry/mocks/MockModule.sol";
import { MockOrchestratorModule } from "test/foundry/mocks/MockOrchestratorModule.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { IGovernable } from "contracts/interfaces/governance/IGovernable.sol";
import { GovernanceLib } from "contracts/lib/GovernanceLib.sol";

contract GovernanceTest is Test {
    AccessController public accessController;
    IPAccountRegistry public ipAccountRegistry;
    IModuleRegistry public moduleRegistry;
    IPAccountImpl public implementation;
    MockERC721 nft = new MockERC721("MockERC721");
    MockModule public mockModule;
    MockModule public moduleWithoutPermission;
    IIPAccount public ipAccount;
    ERC6551Registry public erc6551Registry = new ERC6551Registry();
    address owner = vm.addr(1);
    uint256 tokenId = 100;
    Governance public governance;

    function setUp() public {
        governance = new Governance(address(this));
        accessController = new AccessController(address(governance));
        implementation = new IPAccountImpl();
        ipAccountRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(implementation)
        );
        moduleRegistry = new ModuleRegistry(address(governance));
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
        nft.mintId(owner, tokenId);
        address deployedAccount = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), tokenId);
        ipAccount = IIPAccount(payable(deployedAccount));

        mockModule = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule");
    }

    function test_Governance_registerModuleSuccess() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));
    }

    function test_Governance_removeModuleSuccess() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));
        moduleRegistry.removeModule("MockModule");
        assertEq(moduleRegistry.getModule("MockModule"), address(0));
        assertFalse(moduleRegistry.isRegistered(address(mockModule)));
    }

    function test_Governance_setGlobalPermissionSuccess() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
        assertEq(
            accessController.getPermission(address(0), address(mockModule), address(mockModule2), bytes4(0)),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_registerModuleWithNonAdmin() public {
        vm.prank(address(0x777));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_revert_removeModuleWithNonAdmin() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));
        vm.prank(address(0x777));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.removeModule("MockModule");
    }

    function test_Governance_revert_setGlobalPermissionNonAdmin() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        vm.prank(address(0x777));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_registerModuleWithNewAdmin() public {
        address newAdmin = vm.addr(3);
        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);
        vm.prank(newAdmin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_setGlobalPermissionWithNewAdmin() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));

        address newAdmin = vm.addr(3);
        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);

        vm.prank(newAdmin);
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_registerModuleWithOldAdmin() public {
        address newAdmin = vm.addr(3);
        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);
        governance.revokeRole(GovernanceLib.PROTOCOL_ADMIN, address(this));

        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_revert_removeModuleWithOldAdmin() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));

        address newAdmin = vm.addr(3);
        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);
        governance.revokeRole(GovernanceLib.PROTOCOL_ADMIN, address(this));

        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.removeModule("MockModule");
    }

    function test_Governance_revert_setGlobalPermissionWithOldAdmin() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));

        address newAdmin = vm.addr(3);
        governance.grantRole(GovernanceLib.PROTOCOL_ADMIN, newAdmin);
        governance.revokeRole(GovernanceLib.PROTOCOL_ADMIN, address(this));

        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_setNewGovernance() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
        assertEq(IGovernable(address(moduleRegistry)).getGovernance(), address(newGovernance));
    }

    function test_Governance_registerModuleWithNewGov() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
        vm.prank(newAdmin);
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_setGlobalPermissionWithNewGov() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));

        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        IGovernable(address(accessController)).setGovernance(address(newGovernance));

        vm.prank(newAdmin);
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_registerModuleWithOldGov() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.registerModule("MockModule", address(mockModule));
    }

    function test_Governance_revert_removeModuleWithOldGov() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        assertEq(moduleRegistry.getModule("MockModule"), address(mockModule));
        assertTrue(moduleRegistry.isRegistered(address(mockModule)));

        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        moduleRegistry.removeModule("MockModule");
    }

    function test_Governance_revert_setGlobalPermissionWithOldGov() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));

        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        IGovernable(address(accessController)).setGovernance(address(newGovernance));

        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_setNewGovernanceZeroAddr() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__ZeroAddress.selector));
        IGovernable(address(moduleRegistry)).setGovernance(address(0));
    }

    function test_Governance_revert_setNewGovernanceNotContract() public {
        vm.expectRevert();
        IGovernable(address(moduleRegistry)).setGovernance(address(0xbeefbeef));
    }

    function test_Governance_revert_setNewGovernanceNotSupportInterface() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__UnsupportedInterface.selector, "IGovernance"));
        IGovernable(address(moduleRegistry)).setGovernance(address(mockModule));
    }

    function test_Governance_revert_setNewGovernanceInconsistentState() public {
        address newAdmin = vm.addr(3);
        Governance newGovernance = new Governance(newAdmin);
        vm.prank(newAdmin);
        newGovernance.setState(GovernanceLib.ProtocolState.Paused);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__InconsistentState.selector));
        IGovernable(address(moduleRegistry)).setGovernance(address(newGovernance));
    }

    function test_Governance_revert_setPermissionWhenPaused() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        governance.setState(GovernanceLib.ProtocolState.Paused);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__ProtocolPaused.selector));
        accessController.setPermission(
            address(ipAccount),
            address(mockModule),
            address(mockModule2),
            bytes4(0),
            AccessPermission.ALLOW
        );
    }

    function test_Governance_revert_checkPermissionWhenPaused() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        governance.setState(GovernanceLib.ProtocolState.Paused);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__ProtocolPaused.selector));
        accessController.checkPermission(address(ipAccount), address(mockModule), address(mockModule2), bytes4(0));
    }

    function test_Governance_revert_checkPermissionUnPausedThenPauseThenUnPause() public {
        MockModule mockModule2 = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule2");
        moduleRegistry.registerModule("MockModule2", address(mockModule2));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(mockModule),
                address(mockModule2),
                bytes4(0)
            )
        );
        accessController.checkPermission(address(ipAccount), address(mockModule), address(mockModule2), bytes4(0));

        governance.setState(GovernanceLib.ProtocolState.Paused);
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__ProtocolPaused.selector));
        accessController.checkPermission(address(ipAccount), address(mockModule), address(mockModule2), bytes4(0));

        governance.setState(GovernanceLib.ProtocolState.Unpaused);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(mockModule),
                address(mockModule2),
                bytes4(0)
            )
        );
        accessController.checkPermission(address(ipAccount), address(mockModule), address(mockModule2), bytes4(0));
    }

    function test_Governance_revert_setStateWithNonAdmin() public {
        vm.prank(address(0x777));
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__OnlyProtocolAdmin.selector));
        governance.setState(GovernanceLib.ProtocolState.Paused);
    }

    function test_Governance_revert_setSameState() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.Governance__NewStateIsTheSameWithOldState.selector));
        governance.setState(GovernanceLib.ProtocolState.Unpaused);
    }
}
