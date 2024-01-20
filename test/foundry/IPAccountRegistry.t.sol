// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";

import "contracts/registries/IPAccountRegistry.sol";
import "contracts/IPAccountImpl.sol";
import "test/foundry/mocks/MockERC6551Registry.sol";
import "test/foundry/mocks/MockAccessController.sol";

contract RegistryTest is Test {
    IPAccountRegistry public registry;
    IPAccountImpl public implementation;
    MockERC6551Registry public erc6551Registry;
    MockAccessController public accessController;
    uint256 chainId;
    address tokenAddress;
    uint256 tokenId;

    function setUp() public {
        implementation = new IPAccountImpl();
        erc6551Registry = new MockERC6551Registry();
        accessController = new MockAccessController();
        chainId = 100;
        tokenAddress = address(200);
        tokenId = 300;
    }

    function test_IPAccountRegistry_registerIpAccount() public {
        registry = new IPAccountRegistry(address(erc6551Registry), address(accessController), address(implementation));
        address ipAccountAddr;
        ipAccountAddr = registry.registerIpAccount(
            chainId,
            tokenAddress,
            tokenId
        );

        address registryComputedAddress = registry.ipAccount(
            chainId,
            tokenAddress,
            tokenId
        );
        assertEq(ipAccountAddr, registryComputedAddress);

        IPAccountImpl ipAccount = IPAccountImpl(payable(ipAccountAddr));

        (uint256 chainId_, address tokenAddress_, uint256 tokenId_) = ipAccount.token();
        assertEq(chainId_, chainId);
        assertEq(tokenAddress_, tokenAddress);
        assertEq(tokenId_, tokenId);
    }

    function test_IPAccountRegistry_revert_createAccount_ifInitFailed() public {
        // expect init revert for invalid accessController address
        registry = new IPAccountRegistry(address(erc6551Registry), address(0), address(implementation));
        vm.expectRevert("Invalid access controller");
        registry.registerIpAccount(
            chainId,
            tokenAddress,
            tokenId
        );
    }
}
