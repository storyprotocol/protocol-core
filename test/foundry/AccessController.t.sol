// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IIPAccount } from "../../contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "../../contracts/lib/AccessPermission.sol";
import { Errors } from "../../contracts/lib/Errors.sol";
import { TOKEN_WITHDRAWAL_MODULE_KEY } from "../../contracts/lib/modules/Module.sol";
import { TokenWithdrawalModule } from "../../contracts/modules/external/TokenWithdrawalModule.sol";

import { MockModule } from "./mocks/module/MockModule.sol";
import { MockOrchestratorModule } from "./mocks/module/MockOrchestratorModule.sol";
import { MockERC1155 } from "./mocks/token/MockERC1155.sol";
import { MockERC20 } from "./mocks/token/MockERC20.sol";
import { BaseTest } from "./utils/BaseTest.t.sol";

contract AccessControllerTest is BaseTest {
    MockModule public mockModule;
    MockModule public moduleWithoutPermission;
    IIPAccount public ipAccount;
    address public owner = vm.addr(1);
    uint256 public tokenId = 100;

    error ERC721NonexistentToken(uint256 tokenId);

    function setUp() public override {
        super.setUp();
        buildDeployAccessCondition(DeployAccessCondition({ accessController: true, governance: true }));
        deployConditionally();
        postDeploymentSetup();

        mockNFT.mintId(owner, tokenId);
        address deployedAccount = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), tokenId);
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
            abi.encodeWithSelector(
                Errors.AccessController__BothCallerAndRecipientAreNotRegisteredModule.selector,
                signer,
                address(0xbeef)
            )
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

        vm.prank(u.admin);
        accessController.setGlobalPermission(
            address(mockOrchestratorModule),
            address(module1WithPermission),
            mockModule.executeSuccessfully.selector,
            AccessPermission.ALLOW
        );

        vm.prank(u.admin);
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
        vm.prank(u.admin);
        vm.expectRevert(Errors.AccessController__PermissionIsNotValid.selector);
        accessController.setGlobalPermission(
            address(mockModule),
            address(mockModule),
            mockModule.executeNoReturn.selector,
            3
        );
    }

    function test_AccessController_revert_setGlobalPermissionWithZeroSignerAddress() public {
        vm.prank(u.admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessController__SignerIsZeroAddress.selector));
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
            abi.encodeWithSignature("setBatchPermissions((address,address,address,bytes4,uint8)[])", permissionList)
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
            abi.encodeWithSignature("setBatchPermissions((address,address,address,bytes4,uint8)[])", permissionList)
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
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessController__IPAccountIsZeroAddress.selector));
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature("setBatchPermissions((address,address,address,bytes4,uint8)[])", permissionList)
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
        vm.expectRevert(abi.encodeWithSelector(Errors.AccessController__SignerIsZeroAddress.selector));
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature("setBatchPermissions((address,address,address,bytes4,uint8)[])", permissionList)
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
            abi.encodeWithSignature("setBatchPermissions((address,address,address,bytes4,uint8)[])", permissionList)
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
            abi.encodeWithSignature("setBatchPermissions((address,address,address,bytes4,uint8)[])", permissionList)
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

    // test permission was unset after transfer NFT to another account
    function test_AccessController_NFTTransfer() public {
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
        vm.prank(owner);
        mockNFT.transferFrom(owner, address(0xbeefbeef), tokenId);
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ABSTAIN
        );
    }

    // test permission check failure after transfer NFT to another account
    function test_AccessController_revert_NFTTransferCheckPermissionFailure() public {
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
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
        vm.prank(owner);
        mockNFT.transferFrom(owner, address(0xbeefbeef), tokenId);

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

    // test permission still exist after transfer NFT back
    function test_AccessController_NFTTransferBack() public {
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
        vm.prank(owner);
        mockNFT.transferFrom(owner, address(0xbeefbeef), tokenId);

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ABSTAIN
        );

        vm.prank(address(0xbeefbeef));
        mockNFT.transferFrom(address(0xbeefbeef), owner, tokenId);

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            AccessPermission.ALLOW
        );
    }

    // test permission check still pass after transfer NFT back
    function test_AccessController_NFTTransferBackCheckPermission() public {
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
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
        vm.prank(owner);
        mockNFT.transferFrom(owner, address(0xbeefbeef), tokenId);

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

        vm.prank(address(0xbeefbeef));
        mockNFT.transferFrom(address(0xbeefbeef), owner, tokenId);

        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    // test permission was unset after burn NFT
    function test_AccessController_NFTBurn() public {
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
        vm.prank(owner);
        mockNFT.burn(tokenId);
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenId));
        accessController.getPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    // test permission check failed after burn NFT
    function test_AccessController_revert_NFTBurnCheckPermissionFailure() public {
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
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
        vm.prank(owner);
        mockNFT.burn(tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenId));
        accessController.checkPermission(
            address(ipAccount),
            signer,
            address(mockModule),
            mockModule.executeSuccessfully.selector
        );
    }

    // ipAccount transfer ERC721 to another account
    function test_AccessController_ERC721Transfer() public {
        tokenId = 999;
        mockNFT.mintId(address(ipAccount), tokenId);

        address anotherAccount = vm.addr(3);

        TokenWithdrawalModule tokenWithdrawalModule = new TokenWithdrawalModule(
            address(accessController),
            address(ipAccountRegistry)
        );
        moduleRegistry.registerModule(TOKEN_WITHDRAWAL_MODULE_KEY, address(tokenWithdrawalModule));
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                address(tokenWithdrawalModule),
                address(mockNFT),
                mockNFT.transferFrom.selector,
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                address(tokenWithdrawalModule),
                address(mockNFT),
                mockNFT.transferFrom.selector
            ),
            AccessPermission.ALLOW
        );
        vm.prank(owner);
        tokenWithdrawalModule.withdrawERC721(payable(address(ipAccount)), address(mockNFT), tokenId);
        assertEq(mockNFT.ownerOf(tokenId), owner);
    }

    // ipAccount transfer ERC1155 to another account
    function test_AccessController_ERC1155Transfer() public {
        MockERC1155 mock1155 = new MockERC1155("http://token-uri");
        tokenId = 999;
        mock1155.mintId(address(ipAccount), tokenId, 1e18);

        address anotherAccount = vm.addr(3);

        TokenWithdrawalModule tokenWithdrawalModule = new TokenWithdrawalModule(
            address(accessController),
            address(ipAccountRegistry)
        );
        moduleRegistry.registerModule(TOKEN_WITHDRAWAL_MODULE_KEY, address(tokenWithdrawalModule));
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                address(tokenWithdrawalModule),
                address(mock1155),
                mock1155.safeTransferFrom.selector,
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                address(tokenWithdrawalModule),
                address(mock1155),
                mock1155.safeTransferFrom.selector
            ),
            AccessPermission.ALLOW
        );
        vm.prank(owner);
        tokenWithdrawalModule.withdrawERC1155(payable(address(ipAccount)), address(mock1155), tokenId, 1e18);
        assertEq(mock1155.balanceOf(owner, tokenId), 1e18);
    }
    // ipAccount transfer ERC20 to another account
    function test_AccessController_ERC20Transfer() public {
        MockERC20 mock20 = new MockERC20();
        mock20.mint(address(ipAccount), 1e18);

        address anotherAccount = vm.addr(3);

        TokenWithdrawalModule tokenWithdrawalModule = new TokenWithdrawalModule(
            address(accessController),
            address(ipAccountRegistry)
        );
        moduleRegistry.registerModule(TOKEN_WITHDRAWAL_MODULE_KEY, address(tokenWithdrawalModule));
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                address(tokenWithdrawalModule),
                address(mock20),
                mock20.transfer.selector,
                AccessPermission.ALLOW
            )
        );
        assertEq(
            accessController.getPermission(
                address(ipAccount),
                address(tokenWithdrawalModule),
                address(mock20),
                mock20.transfer.selector
            ),
            AccessPermission.ALLOW
        );
        vm.prank(owner);
        tokenWithdrawalModule.withdrawERC20(payable(address(ipAccount)), address(mock20), 1e18);
        assertEq(mock20.balanceOf(owner), 1e18);
    }
}
