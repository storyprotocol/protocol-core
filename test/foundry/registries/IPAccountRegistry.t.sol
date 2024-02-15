// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { ERC6551Registry } from "erc6551/ERC6551Registry.sol";

import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";

import { MockAccessController } from "test/foundry/mocks/access/MockAccessController.sol";

contract RegistryTest is Test {
    using IPAccountChecker for IPAccountRegistry;

    IPAccountRegistry public registry;
    IPAccountImpl public implementation;
    ERC6551Registry public erc6551Registry;
    MockAccessController public accessController;
    uint256 internal chainId;
    address internal tokenAddress;
    uint256 internal tokenId;

    function setUp() public {
        implementation = new IPAccountImpl();
        erc6551Registry = new ERC6551Registry();
        accessController = new MockAccessController();
        chainId = 100;
        tokenAddress = address(200);
        tokenId = 300;
    }

    function test_IPAccountRegistry_registerIpAccount() public {
        registry = new IPAccountRegistry(address(erc6551Registry), address(accessController), address(implementation));
        address ipAccountAddr;
        ipAccountAddr = registry.registerIpAccount(chainId, tokenAddress, tokenId);

        address registryComputedAddress = registry.ipAccount(chainId, tokenAddress, tokenId);
        assertEq(ipAccountAddr, registryComputedAddress);

        IPAccountImpl ipAccount = IPAccountImpl(payable(ipAccountAddr));

        (uint256 chainId_, address tokenAddress_, uint256 tokenId_) = ipAccount.token();
        assertEq(chainId_, chainId);
        assertEq(tokenAddress_, tokenAddress);
        assertEq(tokenId_, tokenId);

        assertTrue(registry.isRegistered(chainId, tokenAddress, tokenId));
    }

    function test_IPAccountRegistry_revert_createAccount_ifInitFailed() public {
        // expect init revert for invalid accessController address
        registry = new IPAccountRegistry(address(erc6551Registry), address(0), address(implementation));
        vm.expectRevert("Invalid access controller");
        registry.registerIpAccount(chainId, tokenAddress, tokenId);
    }
}
