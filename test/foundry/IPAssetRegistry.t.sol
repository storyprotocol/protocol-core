// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "./utils/BaseTest.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IP } from "contracts/lib/IP.sol";
import { MetadataProviderV1 } from "contracts/registries/metadata/MetadataProviderV1.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IP Asset Registry Testing Contract
/// @notice Contract for testing core IP registration.
contract IPAssetRegistryTest is BaseTest {

    // Default IP record attributes.
    string public constant IP_NAME = "IPAsset";
    string public constant IP_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant IP_HASH = "0x0f";
    string public constant IP_EXTERNAL_URL = "https://storyprotocol.xyz";

    /// @notice Placeholder for registration module.
    address public registrationModule = vm.addr(0x1337);

    /// @notice Placeholder for test resolver addresses.
    address public resolver = vm.addr(0x6969);
    address public resolver2 = vm.addr(0x6978);

    /// @notice The IP asset registry SUT.
    IPAssetRegistry public registry;

    /// @notice The module registry used for protocol module identification.
    IModuleRegistry public moduleRegistry;

    /// @notice The IP account registry used for account creation.
    IPAccountRegistry public ipAccountRegistry;

    /// @notice Mock NFT address for IP registration testing.
    address public tokenAddress;

    /// @notice Mock NFT tokenId for IP registration testing.
    uint256 public tokenId;

    /// @notice ERC-6551 public registry.
    address public erc6551Registry;

    /// @notice Mock IP account implementation address.
    address public ipAccountImpl;

    /// @notice The expected IP account or IP identifier.
    address public ipId;

    /// @notice Initializes the IP asset registry testing contract.
    function setUp() public virtual override {
        BaseTest.setUp();
        address accessController = address(new MockAccessController());
        erc6551Registry = address(new ERC6551Registry());
        moduleRegistry = IModuleRegistry(
            address(new MockModuleRegistry(registrationModule))
        );
        ipAccountImpl = address(new IPAccountImpl());
        ipAccountRegistry = new IPAccountRegistry(
            erc6551Registry,
            accessController,
            ipAccountImpl
        );
        registry = new IPAssetRegistry(
            accessController,
            erc6551Registry,
            ipAccountImpl
        );
        MockERC721 erc721 = new MockERC721("MockERC721");
        tokenAddress = address(erc721);
        tokenId = erc721.mintId(alice, 99);

        assertEq(ipAccountRegistry.getIPAccountImpl(), ipAccountImpl);
        ipId = _getAccount(
            ipAccountImpl,
            block.chainid,
            tokenAddress,
            tokenId,
            ipAccountRegistry.IP_ACCOUNT_SALT()
        );
    }

    /// @notice Tests retrieval of IP canonical IDs.
    function test_IPAssetRegistry_IpId() public {
        assertEq(
            registry.ipId(block.chainid, tokenAddress, tokenId),
            _getAccount(
                ipAccountImpl,
                block.chainid,
                tokenAddress,
                tokenId,
                ipAccountRegistry.IP_ACCOUNT_SALT()
            )
        );
    }

    /// @notice Tests registration of IP assets.
    function test_IPAssetRegistry_Register() public {
        uint256 totalSupply = registry.totalSupply();

        // Ensure unregistered IP preconditions are satisfied.
        assertEq(registry.resolver(ipId), address(0));
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        bytes memory metadata = _generateMetadata();

        // Ensure all expected events are emitted.
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPResolverSet(ipId, resolver);
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            address(registry.metadataProvider()),
            metadata
        );
        vm.prank(registrationModule);
        registry.register(
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            true,
            metadata
        );

        /// Ensures IP asset post-registration conditions are met.
        assertEq(registry.resolver(ipId), resolver);
        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(registry.isRegistered(ipId));
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Tests registration of IP assets with lazy account creation.
    function test_IPAssetRegistry_RegisterWithoutAccount() public {
        uint256 totalSupply = registry.totalSupply();
        // Ensure unregistered IP preconditions are satisfied.
        assertEq(registry.resolver(ipId), address(0));
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));

        bytes memory metadata = _generateMetadata();
        // Ensure all expected events are emitted.
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPResolverSet(ipId, resolver);
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            address(registry.metadataProvider()),
            metadata
        );
        vm.prank(registrationModule);
        registry.register(
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            false,
            metadata
        );

        /// Ensures IP asset post-registration conditions are met.
        assertEq(registry.resolver(ipId), resolver);
        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Tests registration of IP assets works with existing IP accounts.
    function test_IPAssetRegistry_RegisterExistingAccount() public {
        registry.registerIpAccount(
            block.chainid,
            tokenAddress,
            tokenId
        );
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        vm.prank(registrationModule);
        bytes memory metadata = _generateMetadata();
        registry.register(
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            true,
            metadata
        );

    }

    /// @notice Tests registration of IP reverts when an IP has already been registered.
    function test_IPAssetRegistry_Register_Reverts_ExistingRegistration() public {
        vm.startPrank(registrationModule);
        bytes memory metadata = _generateMetadata();
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, metadata);
        vm.expectRevert(Errors.IPAssetRegistry__AlreadyRegistered.selector);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, metadata);
    }

    /// @notice Tests registration of IP reverts if not called by a registration module.
    function test_IPAssetRegistry_Register_Reverts_InvalidRegistrationModule() public {
        bytes memory metadata = _generateMetadata();
        vm.expectRevert(Errors.IPAssetRegistry__Unauthorized.selector);
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, metadata);
    }

    /// @notice Tests IP resolver setting works.
    function test_IPAssetRegistry_SetResolver() public {
        vm.startPrank(registrationModule);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, _generateMetadata());
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPResolverSet(
            ipId,
            resolver2
        );
        registry.setResolver(ipId, resolver2);
        assertEq(registry.resolver(ipId), resolver2);

        // Check that resolvers can be reassigned.
        vm.expectEmit(true, true, true, true);
        emit IIPAssetRegistry.IPResolverSet(
            ipId,
            resolver
        );
        registry.setResolver(ipId, resolver);
        assertEq(registry.resolver(ipId), resolver);
    }

    /// @notice Tests IP resolver setting reverts if an IP is not yet registered.
    function test_IPAssetRegistry_SetResolver_Reverts_NotYetRegistered() public {
        vm.startPrank(alice);
        vm.expectRevert(Errors.IPAssetRegistry__NotYetRegistered.selector);
        registry.setResolver(ipId, resolver);
    }

    /// @notice Helper function for generating an account address.
    function _getAccount(
        address impl,
        uint256 chainId,
        address contractAddress,
        uint256 contractId,
        bytes32 salt
    ) internal view returns (address) {
        return ERC6551Registry(erc6551Registry).account(
            impl,
            salt,
            chainId,
            contractAddress,
            contractId
        );
    }

    function _generateMetadata() internal view returns (bytes memory) {
        return abi.encode(
            IP.MetadataV1({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: uint64(block.timestamp),
                registrant: alice,
                uri: IP_EXTERNAL_URL

            })
        );
    }

}
