// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "./utils/BaseTest.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IP Record Registry Testing Contract
/// @notice Contract for testing core IP registration.
contract IPRecordRegistryTest is BaseTest {

    /// @notice Placeholder for registration module.
    address public registrationModule = vm.addr(0x1337);

    /// @notice Placeholder for test resolver addresses.
    address public resolver = vm.addr(0x6969);
    address public resolver2 = vm.addr(0x6978);

    /// @notice The IP record registry SUT.
    IPRecordRegistry public registry;

    /// @notice The module registry used for protocol module identification.
    IModuleRegistry public moduleRegistry;
    
    /// @notice The IP account registry used for account creation.
    IPAccountRegistry public ipAccountRegistry;

    /// @notice The IP metadata provider associated with an IP.
    IPMetadataProvider public metadataProvider;

    /// @notice Mock NFT address for IP registration testing.
    address public tokenAddress;

    /// @notice Mock NFT tokenId for IP registration testing.
    uint256 public tokenId;

    /// @notice ERC-6551 public registry.
    address public erc6551Registry;

    /// @notice Mock IP account implementation address.
    address public ipAccountImpl;

    /// @notice Initializes the IP record registry testing contract.
    function setUp() public virtual override {
        BaseTest.setUp();
        address accessController = address(new MockAccessController());
        erc6551Registry = address(new ERC6551Registry());
        moduleRegistry = IModuleRegistry(
            address(new MockModuleRegistry(registrationModule))
        );
        metadataProvider = new IPMetadataProvider(address(moduleRegistry));
        ipAccountImpl = address(new IPAccountImpl());
        ipAccountRegistry = new IPAccountRegistry(
            erc6551Registry,
            accessController,
            ipAccountImpl
        );
        registry = new IPRecordRegistry(
            address(moduleRegistry),
            address(ipAccountRegistry)
        );
        MockERC721 erc721 = new MockERC721("MockERC721");
        tokenAddress = address(erc721);
        tokenId = erc721.mintId(alice, 99);

        assertEq(ipAccountRegistry.getIPAccountImpl(), ipAccountImpl);
    }

    /// @notice Tests IP record registry initialization.
    function test_IPRecordRegistry_Constructor() public {
        assertEq(address(registry.MODULE_REGISTRY()), address(moduleRegistry));
        assertEq(address(registry.IP_ACCOUNT_REGISTRY()), address(ipAccountRegistry));
    }

    /// @notice Tests retrieval of IP canonical IDs.
    function test_IPRecordRegistry_IpId() public {
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

    /// @notice Tests registration of IP records.
    function test_IPRecordRegistry_Register() public {
        uint256 totalSupply = registry.totalSupply();
        address ipId = _getAccount(
            ipAccountImpl,
            block.chainid,
            tokenAddress,
            tokenId,
            ipAccountRegistry.IP_ACCOUNT_SALT()
        );

        // Ensure unregistered IP preconditions are satisfied.
        assertEq(registry.resolver(ipId), address(0));
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!registry.isRegistered(block.chainid, tokenAddress, tokenId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        
        // Ensure all expected events are emitted.
        vm.expectEmit(true, true, true, true);
        emit IIPRecordRegistry.IPAccountSet(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId
        );
        vm.expectEmit(true, true, true, true);
        emit IIPRecordRegistry.IPResolverSet(ipId, resolver);
        vm.expectEmit(true, true, true, true);
        emit IIPRecordRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            address(metadataProvider)
        );
        vm.prank(registrationModule);
        registry.register(
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            true,
            address(metadataProvider)
        );

        /// Ensures IP record post-registration conditions are met.
        assertEq(registry.resolver(ipId), resolver);
        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(registry.isRegistered(ipId));
        assertTrue(registry.isRegistered(block.chainid, tokenAddress, tokenId));
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Tests registration of IP records with lazy account creation.
    function test_IPRecordRegistry_RegisterWithoutAccount() public {
        uint256 totalSupply = registry.totalSupply();
        address ipId = _getAccount(
            ipAccountImpl,
            block.chainid,
            tokenAddress,
            tokenId,
            ipAccountRegistry.IP_ACCOUNT_SALT()
        );

        // Ensure unregistered IP preconditions are satisfied.
        assertEq(registry.resolver(ipId), address(0));
        assertTrue(!registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        
        // Ensure all expected events are emitted.
        vm.expectEmit(true, true, true, true);
        emit IIPRecordRegistry.IPResolverSet(ipId, resolver);
        vm.expectEmit(true, true, true, true);
        emit IIPRecordRegistry.IPRegistered(
            ipId,
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            address(metadataProvider)
        );
        vm.prank(registrationModule);
        registry.register(
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            false,
            address(metadataProvider)
        );

        /// Ensures IP record post-registration conditions are met.
        assertEq(registry.resolver(ipId), resolver);
        assertEq(totalSupply + 1, registry.totalSupply());
        assertTrue(registry.isRegistered(ipId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Tests registration of IP records works with existing IP accounts.
    function test_IPRecordRegistry_RegisterExistingAccount() public {
        registry.createIPAccount(block.chainid, tokenAddress, tokenId);
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        vm.prank(registrationModule);
        registry.register(
            block.chainid,
            tokenAddress,
            tokenId,
            resolver,
            true,
            address(metadataProvider)
        );

    }

    /// @notice Tests registration of IP reverts when an IP has already been registered.
    function test_IPRecordRegistry_Register_Reverts_ExistingRegistration() public {
        vm.startPrank(registrationModule);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, address(metadataProvider));
        vm.expectRevert(Errors.IPRecordRegistry_AlreadyRegistered.selector);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, address(metadataProvider));
    }

    /// @notice Tests registration of IP reverts if not called by a registration module.
    function test_IPRecordRegistry_Register_Reverts_InvalidRegistrationModule() public {
        vm.expectRevert(Errors.IPRecordRegistry_Unauthorized.selector);
        vm.prank(alice);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, address(metadataProvider));
    }

    /// @notice Tests generic IP account creation works.
    function test_IPRecordRegistry_CreateIPAccount() public {
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        registry.createIPAccount(block.chainid, tokenAddress, tokenId);
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Tests IP account creation reverts if one already exists.
    function test_IPRecordRegistry_CreateIPAccount_Reverts_AlreadyCreated() public {
        registry.createIPAccount(block.chainid, tokenAddress, tokenId);
        vm.expectRevert(Errors.IPRecordRegistry_IPAccountAlreadyCreated.selector);
        registry.createIPAccount(block.chainid, tokenAddress, tokenId);
    }

    /// @notice Tests IP resolver setting works.
    function test_IPRecordRegistry_SetResolver() public {
        address ipId = _getAccount(
            ipAccountImpl,
            block.chainid,
            tokenAddress,
            tokenId,
            ipAccountRegistry.IP_ACCOUNT_SALT()
        );
        vm.startPrank(registrationModule);
        registry.register(block.chainid, tokenAddress, tokenId, resolver, false, address(metadataProvider));

        vm.expectEmit(true, true, true, true);
        emit IIPRecordRegistry.IPResolverSet(
            ipId,
            resolver2
        );
        registry.setResolver(block.chainid, tokenAddress, tokenId, resolver2);
        assertEq(registry.resolver(block.chainid, tokenAddress, tokenId), resolver2);

        // Check that resolvers can be reassigned.
        vm.expectEmit(true, true, true, true);
        emit IIPRecordRegistry.IPResolverSet(
            ipId,
            resolver
        );
        registry.setResolver(ipId, resolver);
        assertEq(registry.resolver(ipId), resolver);
    }

    /// @notice Tests IP resolver setting reverts if an IP is not yet registered.
    function test_IPRecordRegistry_SetResolver_Reverts_NotYetRegistered() public {
        vm.startPrank(registrationModule);
        vm.expectRevert(Errors.IPRecordRegistry_NotYetRegistered.selector);
        registry.setResolver(block.chainid, tokenAddress, tokenId, resolver);
    }

    /// @notice Tests IP resolver setting reverts if the resolver is invalid.
    function test_IPRecordRegistry_SetResolver_Reverts_ResolverInvalid() public {
        vm.startPrank(registrationModule);
        vm.expectRevert(Errors.IPRecordRegistry_ResolverInvalid.selector);
        registry.setResolver(block.chainid, tokenAddress, tokenId, address(0));
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

}
