// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import "lib/reference/src/interfaces/IERC6551Account.sol";

import "contracts/IPAccountImpl.sol";
import "contracts/interfaces/IIPAccount.sol";
import "contracts/registries/IPAccountRegistry.sol";
import "contracts/registries/ModuleRegistry.sol";

import "test/foundry/mocks/MockAccessController.sol";
import "test/foundry/mocks/MockERC721.sol";
import "test/foundry/mocks/MockModule.sol";
import { Governance } from "contracts/governance/Governance.sol";

contract IPAccountTest is Test {
    IPAccountRegistry public registry;
    IPAccountImpl public implementation;
    MockERC721 nft = new MockERC721("Mock");
    ERC6551Registry public erc6551Registry = new ERC6551Registry();
    MockAccessController public accessController = new MockAccessController();
    ModuleRegistry public moduleRegistry;
    MockModule public module;
    Governance public governance;

    function setUp() public {
        governance = new Governance(address(this));
        moduleRegistry = new ModuleRegistry(address(governance));
        implementation = new IPAccountImpl();
        registry = new IPAccountRegistry(address(erc6551Registry), address(accessController), address(implementation));
        module = new MockModule(address(registry), address(moduleRegistry), "MockModule");
    }

    function test_IPAccount_Idempotency() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        address predictedAccount = registry.ipAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        nft.mintId(owner, tokenId);

        vm.prank(owner, owner);

        address deployedAccount = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        assertTrue(deployedAccount != address(0));

        assertEq(predictedAccount, deployedAccount);

        // Create account twice
        deployedAccount = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );
        assertEq(predictedAccount, deployedAccount);
    }

    function test_IPAccount_TokenAndOwnership() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        IIPAccount ipAccount = IIPAccount(payable(account));

        // Check token and owner functions
        (uint256 chainId_, address tokenAddress_, uint256 tokenId_) = ipAccount.token();
        assertEq(chainId_, block.chainid);
        assertEq(tokenAddress_, address(nft));
        assertEq(tokenId_, tokenId);
        assertEq(ipAccount.isValidSigner(vm.addr(2), ""), bytes4(0));
        assertEq(ipAccount.isValidSigner(owner, ""), IERC6551Account.isValidSigner.selector);

        // Transfer token to new owner and make sure account owner changes
        address newOwner = vm.addr(2);
        vm.prank(owner);
        nft.safeTransferFrom(owner, newOwner, tokenId);
        assertEq(
            ipAccount.isValidSigner(newOwner, ""),
            IERC6551Account.isValidSigner.selector
        );
    }

    function test_IPAccount_OwnerExecutionPass() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        uint256 subTokenId = 111;
        nft.mintId(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(owner);
        bytes memory result = ipAccount.execute(address(module), 0, abi.encodeWithSignature("executeSuccessfully(string)", "test"));
        assertEq("test", abi.decode(result, (string)));

        assertEq(ipAccount.state(), 1);
    }

    function test_IPAccount_revert_NonOwnerNoPermissionToExecute() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        uint256 subTokenId = 111;
        nft.mintId(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(vm.addr(3));
        vm.expectRevert("Invalid signer");
        ipAccount.execute(address(module), 0, abi.encodeWithSignature("executeSuccessfully(string)", "test"));
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_OwnerExecuteFailed() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        uint256 subTokenId = 111;
        nft.mintId(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(owner);
        vm.expectRevert("MockModule: executeRevert");
        ipAccount.execute(address(module), 0, abi.encodeWithSignature("executeRevert()"));
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_ERC721Receive() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mintId(owner, tokenId);

        vm.prank(owner, owner);
        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        address otherOwner = vm.addr(2);
        uint256 otherTokenId = 200;
        nft.mintId(otherOwner, otherTokenId);
        vm.prank(otherOwner);
        nft.safeTransferFrom(otherOwner, account, otherTokenId);
        assertEq(nft.balanceOf(account), 1);
        assertEq(nft.ownerOf(otherTokenId), account);
    }
}