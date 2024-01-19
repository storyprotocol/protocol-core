// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import "contracts/registries/IPAccountRegistry.sol";
import "contracts/IPAccountImpl.sol";
import "contracts/interfaces/IIPAccount.sol";
import "contracts/interfaces/erc6551/IERC6551Account.sol";
import "test/foundry/mocks/MockERC721.sol";
import "test/foundry/mocks/MockERC6551Registry.sol";
import "test/foundry/mocks/MockAccessController.sol";
import "test/foundry/mocks/MockModule.sol";
import "contracts/registries/ModuleRegistry.sol";

contract IPAccountTest is Test {
    IPAccountRegistry public registry;
    IPAccountImpl public implementation;
    MockERC721 nft = new MockERC721();
    MockERC6551Registry public erc6551Registry = new MockERC6551Registry();
    MockAccessController public accessController = new MockAccessController();
    ModuleRegistry public moduleRegistry = new ModuleRegistry();
    MockModule public module;


    function setUp() public {
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

        nft.mint(owner, tokenId);

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

        nft.mint(owner, tokenId);

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

        nft.mint(owner, tokenId);

        vm.prank(owner, owner);
        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        uint256 subTokenId = 111;
        nft.mint(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(owner);
        bytes memory result = ipAccount.execute(address(module), 0, abi.encodeWithSignature("executeSuccessfully(string)", "test"));
        assertEq("test", abi.decode(result, (string)));

        assertEq(ipAccount.state(), 1);
    }

    function test_IPAccount_revert_NonOwnerNoPermissionToExecute() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mint(owner, tokenId);

        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        uint256 subTokenId = 111;
        nft.mint(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(vm.addr(3));
        vm.expectRevert("Invalid signer");
        ipAccount.execute(address(module), 0, abi.encodeWithSignature("executeSuccessfully(string)", "test"));
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_revert_OwnerExecuteFailed() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mint(owner, tokenId);

        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        uint256 subTokenId = 111;
        nft.mint(account, subTokenId);

        IIPAccount ipAccount = IIPAccount(payable(account));

        vm.prank(owner);
        vm.expectRevert("MockModule: executeRevert");
        ipAccount.execute(address(module), 0, abi.encodeWithSignature("executeRevert()"));
        assertEq(ipAccount.state(), 0);
    }

    function test_IPAccount_ERC721Receive() public {
        address owner = vm.addr(1);
        uint256 tokenId = 100;

        nft.mint(owner, tokenId);

        vm.prank(owner, owner);
        address account = registry.registerIpAccount(
            block.chainid,
            address(nft),
            tokenId
        );

        address otherOwner = vm.addr(2);
        uint256 otherTokenId = 200;
        nft.mint(otherOwner, otherTokenId);
        vm.prank(otherOwner);
        nft.safeTransferFrom(otherOwner, account, otherTokenId);
        assertEq(nft.balanceOf(account), 1);
        assertEq(nft.ownerOf(otherTokenId), account);
    }
}
