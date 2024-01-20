// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import "contracts/registries/IPAccountRegistry.sol";
import "contracts/IPAccountImpl.sol";
import "contracts/interfaces/IIPAccount.sol";
import "lib/reference/src/interfaces/IERC6551Account.sol";
import "test/foundry/mocks/MockERC721.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import "test/foundry/mocks/MockAccessController.sol";
import "test/foundry/mocks/MockModule.sol";
import "test/foundry/mocks/MockOrchestratorModule.sol";
import "contracts/interfaces/registries/IModuleRegistry.sol";
import "contracts/registries/ModuleRegistry.sol";
import "contracts/AccessController.sol";
import "contracts/lib/AccessPermission.sol";

contract AccessControllerTest is Test {
    AccessController public accessController;
    IPAccountRegistry public ipAccountRegistry;
    IModuleRegistry public moduleRegistry;
    IPAccountImpl public implementation;
    MockERC721 nft = new MockERC721();
    MockModule public mockModule;
    MockModule public moduleWithoutPermission;
    IIPAccount public ipAccount;
    ERC6551Registry public erc6551Registry = new ERC6551Registry();
    address owner = vm.addr(1);
    uint256 tokenId = 100;

    function setUp() public {
        accessController = new AccessController();
        implementation = new IPAccountImpl();
        ipAccountRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(implementation)
        );
        moduleRegistry = new ModuleRegistry();
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
        nft.mint(owner, tokenId);
        address deployedAccount = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), tokenId);
        ipAccount = IIPAccount(payable(deployedAccount));

        mockModule = new MockModule(
            address(ipAccountRegistry),
            address(moduleRegistry),
            "MockModule"
        );
//        moduleWithoutPermission = new MockModule(
//            address(ipAccountRegistry),
//            address(moduleRegistry),
//            "ModuleWithoutPermission"
//        );
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
        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            true
        );
    }

    function test_AccessController_revert_NonOwnerCannotSetPermission() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));
        address signer = vm.addr(2);
        address nonOwner = vm.addr(3);
        vm.prank(nonOwner);
        vm.expectRevert("Invalid signer");
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                bytes4(0)
            ),
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
        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            true
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                bytes4(0)
            ),
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
        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            false
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(0),
                bytes4(0)
            ),
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
        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            true
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(0),
                bytes4(0)
            ),
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
        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            false
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                bytes4(0)
            ),
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

        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            true
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                bytes4(0)
            ),
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

        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            false
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(0),
                bytes4(0)
            ),
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

        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            true
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(0),
                bytes4(0)
            ),
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

        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            false
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(0),
                bytes4(0)
            ),
            AccessPermission.DENY
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                bytes4(0)
            ),
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

        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            true
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
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(0),
                bytes4(0)
            ),
            AccessPermission.ALLOW
        );

        assertEq(
            accessController.getPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                bytes4(0)
            ),
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

        assertEq(
            accessController.checkPermission(
                address(ipAccount),
                signer,
                address(mockModule),
                mockModule.executeSuccessfully.selector
            ),
            false
        );
    }

    function test_AccessController_ipAccountOwnerCanCallAnyModuleWithoutPermission() public {
        moduleRegistry.registerModule("MockModule", address(mockModule));

        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(mockModule),
            0,
            abi.encodeWithSignature(
                "executeSuccessfully(string)",
                "testParameter"
            )
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
            abi.encodeWithSignature(
                "callAnotherModule(string)",
                "AnotherMockModule"
            )
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
        vm.expectRevert("Invalid signer");
        mockOrchestratorModule.workflowFailure(payable(address(ipAccount)));

    }

}
