// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { IAccessController } from "contracts/interfaces/IAccessController.sol";
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
import { MockAccessControlledModule } from "test/foundry/mocks/MockAccessControlledModule.sol";

contract AccessControlledTest is Test {
    AccessController public accessController;
    IPAccountRegistry public ipAccountRegistry;
    IModuleRegistry public moduleRegistry;
    IPAccountImpl public implementation;
    MockERC721 nft = new MockERC721("MockERC721");
    MockAccessControlledModule public mockModule;
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

        mockModule = new MockAccessControlledModule(
            address(accessController),
            address(ipAccountRegistry),
            address(moduleRegistry),
            "MockAccessControlledModule"
        );
        moduleRegistry.registerModule("MockAccessControlledModule", address(mockModule));
    }

    // call only ipAccount function with an ipAccount
    // call only ipAccount function with non ipAccount
    // call only ipAccount function with an ipAccount and fail
    // call ipAccount or permission function with caller is ipAccount
    // call ipAccount or permission function with caller is not ipAccount but has permission
    // call ipAccount or permission function with caller is not ipAccount and has no permission
    // call ipAccount or permission function with caller is not ipAccount and module not registered
    // call ipAccount or permission function with pass in non ipAccount
    // call ipAccount or permission function with fail
    // call customized function with ipAccount (call _hasPermission)
    // call customized function with non ipAccount but has permission
    // call customized function  pass in a non ipAccount
    // call customized function with fail (call _hasPermission)

    function test_AccessControlled_callOnlyIpAccountFunction_withIpAccount() public {
        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(mockModule),
            0,
            abi.encodeWithSignature("onlyIpAccountFunction(string,bool)", "test", true)
        );
        assertEq("test", abi.decode(result, (string)));
    }

    function test_AccessControlled_revert_callOnlyIpAccountFunction_withNonIpAccount() public {
        address nonOwner = vm.addr(3);
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__CallerIsNotIpAccount.selector, nonOwner));
        vm.prank(nonOwner);
        mockModule.onlyIpAccountFunction("test", true);
    }

    function test_AccessControlled_revert_callOnlyIpAccountFunctionFail_withIpAccount() public {
        vm.expectRevert("expected failure");
        vm.prank(owner);
        ipAccount.execute(
            address(mockModule),
            0,
            abi.encodeWithSignature("onlyIpAccountFunction(string,bool)", "test", false)
        );
    }

    function test_AccessControlled_callIpAccountOrPermissionFunction_withIpAccount() public {
        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(mockModule),
            0,
            abi.encodeWithSignature(
                "ipAccountOrPermissionFunction(address,string,bool)",
                address(ipAccount),
                "test",
                true
            )
        );
        assertEq("test", abi.decode(result, (string)));
    }

    function test_AccessControlled_callIpAccountOrPermissionFunction_withIpAccountOwner() public {
        vm.prank(owner);
        string memory result = mockModule.ipAccountOrPermissionFunction(address(ipAccount), "test", true);
        assertEq("test", result);
    }

    function test_AccessControlled_callIpAccountOrPermissionFunction_withDelegatedSigner() public {
        address signer = vm.addr(2);
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.ipAccountOrPermissionFunction.selector,
                AccessPermission.ALLOW
            )
        );
        vm.prank(signer);
        string memory result = mockModule.ipAccountOrPermissionFunction(address(ipAccount), "test", true);
        assertEq("test", result);
    }

    function test_AccessControlled_revert_callIpAccountOrPermissionFunction_withOtherIpAccount() public {
        nft.mintId(owner, 101);
        address otherIpAccountAddr = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 101);
        IIPAccount otherIpAccount = IIPAccount(payable(otherIpAccountAddr));
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(otherIpAccount),
                address(mockModule),
                mockModule.ipAccountOrPermissionFunction.selector
            )
        );
        vm.prank(owner);
        otherIpAccount.execute(
            address(mockModule),
            0,
            abi.encodeWithSignature(
                "ipAccountOrPermissionFunction(address,string,bool)",
                address(ipAccount),
                "test",
                true
            )
        );
    }

    function test_AccessControlled_revert_callIpAccountOrPermissionFunction_withNonIpAccountOwner() public {
        address nonOwner = vm.addr(3);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(nonOwner),
                address(mockModule),
                mockModule.ipAccountOrPermissionFunction.selector
            )
        );
        vm.prank(nonOwner);
        mockModule.ipAccountOrPermissionFunction(address(ipAccount), "test", true);
    }

    function test_AccessControlled_revert_callIpAccountOrPermissionFunction_nonRegisteredModule() public {
        MockAccessControlledModule nonRegisteredModule = new MockAccessControlledModule(
            address(accessController),
            address(ipAccountRegistry),
            address(moduleRegistry),
            "NonRegisteredMockAccessControlledModule"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__RecipientIsNotRegisteredModule.selector,
                address(nonRegisteredModule)
            )
        );
        vm.prank(owner);
        nonRegisteredModule.ipAccountOrPermissionFunction(address(ipAccount), "test", true);
    }

    function test_AccessControlled_revert_callIpAccountOrPermissionFunction_passInNonIpAccount() public {
        address nonIpAccount = vm.addr(7);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessControlled__NotIpAccount.selector,
                nonIpAccount
            )
        );
        vm.prank(owner);
        mockModule.ipAccountOrPermissionFunction(nonIpAccount, "test", true);
    }

    function test_AccessControlled_revert_callIpAccountOrPermissionFunctionFail_withIpAccountOwner() public {
        vm.expectRevert("expected failure");
        vm.prank(owner);
        mockModule.ipAccountOrPermissionFunction(address(ipAccount), "test", false);
    }

    function test_AccessControlled_customizedFunctionUsingHasPermission_withIpAccount() public {
        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(mockModule),
            0,
            abi.encodeWithSignature("customizedFunction(address,string,bool)", address(ipAccount), "test", true)
        );
        assertEq("test", abi.decode(result, (string)));
    }

    function test_AccessControlled_customizedFunctionUsingHasPermission_withIpAccountOwner() public {
        vm.prank(owner);
        string memory result = mockModule.customizedFunction(address(ipAccount), "test", true);
        assertEq("test", result);
    }

    function test_AccessControlled_revert_customizedFunctionUsingHasPermission_passInNonIpAccount() public {
        address nonIpAccount = vm.addr(7);
        vm.expectRevert("expected permission check failure");
        vm.prank(owner);
        mockModule.customizedFunction(nonIpAccount, "test", true);
    }

    function test_AccessControlled_revert_customizedFunctionUsingHasPermissionFail_withIpAccountOwner() public {
        vm.expectRevert("expected failure");
        vm.prank(owner);
        mockModule.customizedFunction(address(ipAccount), "test", false);
    }

    function test_AccessControlled_revert_constructor_zeroAddress_accessController() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__ZeroAddress.selector));
        new MockAccessControlledModule(
            address(0),
            address(ipAccountRegistry),
            address(moduleRegistry),
            "MockAccessControlledModule"
        );
    }

    function test_AccessControlled_revert_constructor_zeroAddress_ipAccountRegistry() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessControlled__ZeroAddress.selector));
        new MockAccessControlledModule(
            address(accessController),
            address(0),
            address(moduleRegistry),
            "MockAccessControlledModule"
        );
    }
}
