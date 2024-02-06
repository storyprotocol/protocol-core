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

contract AccessControllerTest is Test {
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

    // test owner can set permission
    // test non owner cannot set specific permission
    // test permission overrides
    // test wildcard permission
    // test whilelist permission
    // test blacklist permission
    // module call ipAccount call module
    // ipAccount call module
    // mock orchestration?

    function test_AccessController_ipAccountOwnerSetPermission() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
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
                mockModule.executeSuccessfully.selector,
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ALLOW
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_revert_NonOwnerCannotSetPermission() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);
        address nonOwner = vm.addr(3);
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                nonOwner,
                address(accessController),
                accessController.setPermission.selector
            )
        );
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector,
                AccessPermission.ALLOW
            )
        );
    }

    function test_AccessController_revert_directSetPermission() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);

        vm.prank(address(ipAccount));
        vm.expectRevert(Errors.AccessController__IPAccountIsZeroAddress.selector);
        accessController.setPermission(
            address(0),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector,
            AccessPermission.ALLOW
        );

        vm.prank(address(ipAccount));
        vm.expectRevert(Errors.AccessController__SignerIsZeroAddress.selector);
        accessController.setPermission(
            address(ipAccount),
            address(0),
            address(mockModule),
            mockModule.executeSuccessfully.selector,
            AccessPermission.ALLOW
        );

        vm.prank(address(ipAccount));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.AccessController__IPAccountIsNotValid.selector, address(0xbeefbeef))
        );
        accessController.setPermission(
            address(0xbeefbeef),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector,
            AccessPermission.ALLOW
        );

        vm.prank(owner); // not calling from ipAccount
        vm.expectRevert(Errors.AccessController__CallerIsNotIPAccount.selector);
        accessController.setPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector,
            AccessPermission.ALLOW
        );

        vm.prank(address(ipAccount)); // not calling from ipAccount
        vm.expectRevert(Errors.AccessController__PermissionIsNotValid.selector);
        accessController.setPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector,
            type(uint8).max
        );
    }

    function test_AccessController_revert_checkPermission() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
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
                bytes4(0),
                AccessPermission.ALLOW
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(Errors.AccessController__RecipientIsNotRegisteredModule.selector, address(0xbeef))
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(0xbeef), // instead of address(mockModule)
            mockModule.executeSuccessfully.selector
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.AccessController__IPAccountIsNotValid.selector, address(0xbeef)));
        accessController.checkPermission(
            address(0xbeef), // invalid IPAccount
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_functionPermissionWildcardAllow() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
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
                bytes4(0),
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(mockModule), bytes4(0)),
            AccessPermission.ALLOW
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ABSTAIN
        );

        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_functionPermissionWildcardDeny() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
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
                bytes4(0),
                AccessPermission.DENY
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(mockModule), bytes4(0)),
            AccessPermission.DENY
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ABSTAIN
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            )
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_toAddressPermissionWildcardAllow() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(0),
                bytes4(0),
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(0), bytes4(0)),
            AccessPermission.ALLOW
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ABSTAIN
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_toAddressPermissionWildcardDeny() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(0),
                bytes4(0),
                AccessPermission.DENY
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(0), bytes4(0)),
            AccessPermission.DENY
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ABSTAIN
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            )
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_overrideFunctionWildcard_allowOverrideDeny() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
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
                bytes4(0),
                AccessPermission.DENY
            )
        );
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector,
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(mockModule), bytes4(0)),
            AccessPermission.DENY
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ALLOW
        );

        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_overrideFunctionWildcard_DenyOverrideAllow() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
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
                bytes4(0),
                AccessPermission.ALLOW
            )
        );
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector,
                AccessPermission.DENY
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(mockModule), bytes4(0)),
            AccessPermission.ALLOW
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.DENY
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            )
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_overrideToAddressWildcard_allowOverrideDeny() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(0),
                bytes4(0),
                AccessPermission.DENY
            )
        );
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector,
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(0), bytes4(0)),
            AccessPermission.DENY
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ALLOW
        );

        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_overrideToAddressWildcard_DenyOverrideAllow() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(0),
                bytes4(0),
                AccessPermission.ALLOW
            )
        );
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector,
                AccessPermission.DENY
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(0), bytes4(0)),
            AccessPermission.ALLOW
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.DENY
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            )
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_functionWildcardOverrideToAddressWildcard_allowOverrideDeny() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(0),
                bytes4(0),
                AccessPermission.DENY
            )
        );
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(mockModule),
                bytes4(0),
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(0), bytes4(0)),
            AccessPermission.DENY
        );

        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(mockModule), bytes4(0)),
            AccessPermission.ALLOW
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ABSTAIN
        );

        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_functionWildcardOverrideToAddressWildcard_denyOverrideAllow() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(0),
                bytes4(0),
                AccessPermission.ALLOW
            )
        );
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(mockModule),
                bytes4(0),
                AccessPermission.DENY
            )
        );
        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(0), bytes4(0)),
            AccessPermission.ALLOW
        );

        assertEq(
            accessController.getPermission(address(ipAccount), signer, address(mockModule), bytes4(0)),
            AccessPermission.DENY
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ABSTAIN
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            )
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    function test_AccessController_ipAccountOwnerCanCallAnyModuleWithoutPermission() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));

        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(mockModule),
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", "testParameter")
        );
        assertEq("testParameter", abi.decode(result, (string)));
    }

    function test_AccessController_moduleCallAnotherModuleViaIpAccount() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        MockModule anotherModule = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "AnotherMockModule"
        );
        moduleRegistry.registerModule("AnotherMockModule", address(anotherModule));

        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                address(mockModule),
                address(anotherModule),
                mockModule.executeSuccessfully.selector,
                AccessPermission.ALLOW
            )
        );

        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(mockModule),
            0,
            abi.encodeWithSignature("callAnotherModule(string)", "AnotherMockModule")
        );
        assertEq("AnotherMockModule", abi.decode(result, (string)));
    }

    function test_AccessController_OrchestratorModuleCallIpAccount() public {
        MockOrchestratorModule mockOrchestratorModule = new MockOrchestratorModule(
            address(ipAccountRegistry),
            address(moduleRegistry)
        );
        moduleRegistry.registerModule("MockOrchestratorModule", address(mockOrchestratorModule));

        MockModule module1WithPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module1WithPermission"
        );
        moduleRegistry.registerModule("Module1WithPermission", address(module1WithPermission));

        MockModule module2WithPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module2WithPermission"
        );
        moduleRegistry.registerModule("Module2WithPermission", address(module2WithPermission));

        MockModule module3WithoutPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module3WithoutPermission"
        );
        moduleRegistry.registerModule("Module3WithoutPermission", address(module3WithoutPermission));

        vm.prank(owner);
        // orchestrator can call any modules through ipAccount
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                address(mockOrchestratorModule),
                address(0),
                bytes4(0),
                AccessPermission.ALLOW
            )
        );

        vm.prank(owner);
        mockOrchestratorModule.workflowPass(payable(address(ipAccount)));
    }

    function test_AccessController_revert_OrchestratorModuleCallIpAccountLackSomeModulePermission() public {
        MockOrchestratorModule mockOrchestratorModule = new MockOrchestratorModule(
            address(ipAccountRegistry),
            address(moduleRegistry)
        );
        moduleRegistry.registerModule("MockOrchestratorModule", address(mockOrchestratorModule));

        MockModule module1WithPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module1WithPermission"
        );
        moduleRegistry.registerModule("Module1WithPermission", address(module1WithPermission));

        MockModule module2WithPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module2WithPermission"
        );
        moduleRegistry.registerModule("Module2WithPermission", address(module2WithPermission));

        MockModule module3WithoutPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module3WithoutPermission"
        );
        moduleRegistry.registerModule("Module3WithoutPermission", address(module3WithoutPermission));

        vm.prank(owner);
        // orchestrator can call any modules through ipAccount
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                address(mockOrchestratorModule),
                address(0),
                bytes4(0),
                AccessPermission.ALLOW
            )
        );

        vm.prank(owner);
        // BUT orchestrator cannot call module3 without permission
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                address(mockOrchestratorModule),
                address(module3WithoutPermission),
                bytes4(0),
                AccessPermission.DENY
            )
        );

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                address(mockOrchestratorModule),
                address(module3WithoutPermission),
                module3WithoutPermission.executeNoReturn.selector
            )
        );
        mockOrchestratorModule.workflowFailure(payable(address(ipAccount)));
    }

    function test_AccessController_OrchestratorModuleWithGlobalPermission() public {
        MockOrchestratorModule mockOrchestratorModule = new MockOrchestratorModule(
            address(ipAccountRegistry),
            address(moduleRegistry)
        );
        moduleRegistry.registerModule("MockOrchestratorModule", address(mockOrchestratorModule));

        MockModule module1WithPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module1WithPermission"
        );
        moduleRegistry.registerModule("Module1WithPermission", address(module1WithPermission));

        MockModule module2WithPermission = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "Module2WithPermission"
        );
        moduleRegistry.registerModule("Module2WithPermission", address(module2WithPermission));

        accessController.setGlobalPermission(
            address(mockOrchestratorModule),
            address(module1WithPermission),
            mockModule.executeSuccessfully.selector,
            AccessPermission.ALLOW
        );

        accessController.setGlobalPermission(
            address(mockOrchestratorModule),
            address(module2WithPermission),
            mockModule.executeNoReturn.selector,
            AccessPermission.ALLOW
        );

        vm.prank(owner);
        mockOrchestratorModule.workflowPass(payable(address(ipAccount)));
    }

    function test_AccessController_revert_setGlobalPermissionWithInvalidPermission() public {
        vm.expectRevert(Errors.AccessController__PermissionIsNotValid.selector);
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule),
            mockModule.executeNoReturn.selector,
            3
        );

    }

    function test_AccessController_revert_setGlobalPermissionWithZeroSignerAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__SignerIsZeroAddress.selector
            )
        );
        accessController.setGlobalPermission(
            address(0),
            address(mockModule),
            mockModule.executeNoReturn.selector,
            AccessPermission.ALLOW
        );

    }

    function test_AccessController_ipAccountOwnerSetBatchPermissions() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);

        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](3);
        permissionList[0] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeSuccessfully.selector,
            permission: AccessPermission.ALLOW
        });
        permissionList[1] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeNoReturn.selector,
            permission: AccessPermission.DENY
        });
        permissionList[2] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeRevert.selector,
            permission: AccessPermission.ALLOW
        });

        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setBatchPermissions((address,address,address,bytes4,uint8)[])",
                permissionList
            )
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ALLOW
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeNoReturn.selector
            ),
            AccessPermission.DENY
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeRevert.selector
            ),
            AccessPermission.ALLOW
        );

        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeNoReturn.selector
            )
        );
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeNoReturn.selector
        );

        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeRevert.selector
        );
    }


    function test_AccessController_revert_NonIpAccountOwnerSetBatchPermissions() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);

        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](3);
        permissionList[0] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeSuccessfully.selector,
            permission: AccessPermission.ALLOW
        });
        permissionList[1] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeNoReturn.selector,
            permission: AccessPermission.DENY
        });
        permissionList[2] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeRevert.selector,
            permission: AccessPermission.ALLOW
        });

        address nonOwner = vm.addr(3);
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__PermissionDenied.selector,
                address(ipAccount),
                nonOwner,
                address(accessController),
                accessController.setBatchPermissions.selector
            )
        );
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setBatchPermissions((address,address,address,bytes4,uint8)[])",
                permissionList
            )
        );
    }

    function test_AccessController_revert_setBatchPermissionsWithZeroIPAccountAddress() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);

        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](3);
        permissionList[0] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeSuccessfully.selector,
            permission: AccessPermission.ALLOW
        });
        permissionList[1] = AccessPermission.Permission({
            ipAccount: address(0),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeNoReturn.selector,
            permission: AccessPermission.DENY
        });
        permissionList[2] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeRevert.selector,
            permission: AccessPermission.ALLOW
        });

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__IPAccountIsZeroAddress.selector
            )
        );
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setBatchPermissions((address,address,address,bytes4,uint8)[])",
                permissionList
            )
        );
    }

    function test_AccessController_revert_setBatchPermissionsWithZeroSignerAddress() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);

        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](3);
        permissionList[0] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeSuccessfully.selector,
            permission: AccessPermission.ALLOW
        });
        permissionList[1] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: address(0),
            to: address(mockModule),
            func: mockModule.executeNoReturn.selector,
            permission: AccessPermission.DENY
        });
        permissionList[2] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeRevert.selector,
            permission: AccessPermission.ALLOW
        });

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.AccessController__SignerIsZeroAddress.selector
            )
        );
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setBatchPermissions((address,address,address,bytes4,uint8)[])",
                permissionList
            )
        );
    }

    function test_AccessController_revert_setBatchPermissionsWithInvalidIPAccount() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);

        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](3);
        permissionList[0] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeSuccessfully.selector,
            permission: AccessPermission.ALLOW
        });
        // invalid ipaccount address
        permissionList[1] = AccessPermission.Permission({
            ipAccount: address(0xbeefbeef),
            signer: address(signer),
            to: address(mockModule),
            func: mockModule.executeNoReturn.selector,
            permission: AccessPermission.DENY
        });
        permissionList[2] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeRevert.selector,
            permission: AccessPermission.ALLOW
        });

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.AccessController__IPAccountIsNotValid.selector, address(0xbeefbeef))
        );
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setBatchPermissions((address,address,address,bytes4,uint8)[])",
                permissionList
            )
        );
    }

    function test_AccessController_revert_setBatchPermissionsWithInvalidPermission() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);

        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](3);
        permissionList[0] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeSuccessfully.selector,
            permission: AccessPermission.ALLOW
        });
        // invalid ipaccount address
        permissionList[1] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: address(signer),
            to: address(mockModule),
            func: mockModule.executeNoReturn.selector,
            permission: 3
        });
        permissionList[2] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeRevert.selector,
            permission: AccessPermission.ALLOW
        });

        vm.prank(owner);
        vm.expectRevert(Errors.AccessController__PermissionIsNotValid.selector);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setBatchPermissions((address,address,address,bytes4,uint8)[])",
                permissionList
            )
        );
    }

    function test_AccessController_revert_setBatchPermissionsButCallerisNotIPAccount() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);

        AccessPermission.Permission[] memory permissionList = new AccessPermission.Permission[](3);
        permissionList[0] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeSuccessfully.selector,
            permission: AccessPermission.ALLOW
        });
        // invalid ipaccount address
        permissionList[1] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: address(signer),
            to: address(mockModule),
            func: mockModule.executeNoReturn.selector,
            permission: 3
        });
        permissionList[2] = AccessPermission.Permission({
            ipAccount: address(ipAccount),
            signer: signer,
            to: address(mockModule),
            func: mockModule.executeRevert.selector,
            permission: AccessPermission.ALLOW
        });

        vm.expectRevert(Errors.AccessController__CallerIsNotIPAccount.selector);
        accessController.setBatchPermissions(permissionList);
    }
}
