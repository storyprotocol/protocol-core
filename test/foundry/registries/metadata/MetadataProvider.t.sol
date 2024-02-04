// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { IP } from "contracts/lib/IP.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { MockMetadataProviderV2 } from "test/foundry/mocks/MockMetadataProviderV2.sol";
import { AccessController } from "contracts/AccessController.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { MetadataProviderV1 } from "contracts/registries/metadata/MetadataProviderV1.sol";
import { IMetadataProvider } from "contracts/interfaces/registries/metadata/IMetadataProvider.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";

/// @title IP Metadata Provider Testing Contract
/// @notice Contract for metadata provider settings.
contract MetadataProviderTest is BaseTest {

    /// @notice Struct depicting the expected upgraded canonical Metadata.
    struct ExpectedUpgradedMetadataV2 {
        ////////////////////////////////////////////////////////////////////////
        //                   Start of V1 Metadata                             //
        ////////////////////////////////////////////////////////////////////////
        // The name associated with the IP.
        string name;
        // A keccak-256 hash of the IP content.
        bytes32 hash;
        // The date which the IP was registered.
        uint64 registrationDate;
        // The address of the initial IP registrant.
        address registrant;
        // An external URI associated with the IP.
        string uri;
        ////////////////////////////////////////////////////////////////////////
        //                   Start of V2 Metadata                             //
        ////////////////////////////////////////////////////////////////////////
        // A nickname to associate with the metadata.
        string nickname;
        // Random decimals to incorporate into the metadata.
        uint256 decimals;
    }

    /// @notice Incompatible upgraded canonical metadata struct.
    struct IncompatibleUpgradedMetadataV2 {
        // The name associated with the IP.
        string name;
        // A keccak-256 hash of the IP content.
        bytes32 hash;

        ////////////////////////////////////////////////////////////////////////
        //             Note:  Missing registration memory encoding           ///
        ////////////////////////////////////////////////////////////////////////
        // The date which the IP was registered.
        // uint64 registrationDate;

        // The address of the initial IP registrant.
        address registrant;
        // An external URI associated with the IP.
        string uri;
        // A nickname to associate with the metadata.
        string nickname;
        // Random decimals to incorporate into the metadata.
        uint256 decimals;
    }


    // Default IP asset metadata attributes.
    string public constant IP_NAME = "IPAsset";
    string public constant IP_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant IP_HASH = "0x99";
    string public constant IP_EXTERNAL_URL = "https://storyprotocol.xyz";
    
    // Default upgraded additional IP asset metadata attributes.
    string public constant IP_NICKNAME = "IP Man";
    uint256 public constant IP_DECIMALS = 9999;

    /// @notice The IP metadata provider SUT.
    MetadataProviderV1 public metadataProvider;

    /// @notice The IP metadata provider to upgrade to.
    MockMetadataProviderV2 public upgradedProvider;

    /// @notice Initial metadata to set for testing.
    bytes public v1Metadata;

    /// @notice Mock IP account to use for testing.
    address public ipId;

    /// @notice Protocol-wide IP registry used for testing metadata upgrades.
    IPAssetRegistry public registry;

    /// @notice Initializes the IP metadata provider contract.
    function setUp() public virtual override {
        BaseTest.setUp();
        v1Metadata = abi.encode(
            IP.MetadataV1({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: uint64(block.timestamp),
                registrant: alice,
                uri: IP_EXTERNAL_URL

            })
        );

        // TODO: Reuse this setup in all tests requiring IPAssetRegistry initialization.
        Governance governance = new Governance(address(this));
        AccessController accessController = new AccessController(address(governance));
        ModuleRegistry moduleRegistry = new ModuleRegistry(address(governance));

        ERC6551Registry erc6551Registry = new ERC6551Registry();
        IPAccountImpl ipAccountImpl = new IPAccountImpl();
        IPAccountRegistry ipAccountRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(ipAccountImpl)
        );
        vm.prank(bob);
        registry = new IPAssetRegistry(
            address(accessController),
            address(erc6551Registry),
            address(ipAccountImpl)
        );
        RoyaltyModule royaltyModule = new RoyaltyModule(address(governance));

        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
        LicenseRegistry licenseRegistry = new LicenseRegistry(
            address(accessController),
            address(registry),
            address(royaltyModule)
        );
        MockERC721 erc721 = new MockERC721("MockERC721");
        uint256 tokenId = erc721.mintId(alice, 99);
        IPResolver resolver = new IPResolver(
            address(accessController),
            address(registry),
            address(licenseRegistry)
        );
        ipId = registry.register(
            block.chainid,
            address(erc721),
            tokenId,
            address(resolver),
            true,
            v1Metadata
        );

        metadataProvider = MetadataProviderV1(registry.metadataProvider());
        upgradedProvider = new MockMetadataProviderV2(address(registry));
    }

    /// @notice Tests IP metadata provider initialization.
    function test_MetadataProvider_Constructor() public {
        metadataProvider = new MetadataProviderV1(address(registry));
        assertEq(address(metadataProvider.IP_ASSET_REGISTRY()), address(registry));
    }

    /// @notice Tests metadata is properly stored.
    function test_MetadataProvider_SetMetadata() public {
        vm.expectEmit(true, true, true, true);
        emit IMetadataProvider.MetadataSet(
            ipId,
            v1Metadata
        );
        vm.prank(address(registry));
        metadataProvider.setMetadata(ipId, v1Metadata);
        assertEq(
            metadataProvider.getMetadata(ipId),
            v1Metadata
        );
        assertEq(metadataProvider.name(ipId), IP_NAME);
        assertEq(metadataProvider.hash(ipId), IP_HASH);
        assertEq(metadataProvider.registrationDate(ipId), uint64(block.timestamp));
        assertEq(metadataProvider.registrant(ipId), alice);
        assertEq(metadataProvider.uri(ipId), IP_EXTERNAL_URL);
    }

    /// @notice Tests metadata set without a name reverts.
    function test_MetadataProvider_SetMetadata_Reverts_InvalidName() public {
        v1Metadata = abi.encode(
            IP.MetadataV1({
                name: "",
                hash: IP_HASH,
                registrationDate: uint64(block.timestamp),
                registrant: alice,
                uri: IP_EXTERNAL_URL

            })
        );
        vm.expectRevert(Errors.MetadataProvider__NameInvalid.selector);
        vm.prank(address(registry));
        metadataProvider.setMetadata(ipId, v1Metadata);
    }

    /// @notice Tests metadata set without a hash reverts.
    function test_MetadataProvider_SetMetadata_Reverts_InvalidHash() public {
        v1Metadata = abi.encode(
            IP.MetadataV1({
                name: IP_NAME,
                hash: "",
                registrationDate: uint64(block.timestamp),
                registrant: alice,
                uri: IP_EXTERNAL_URL

            })
        );
        vm.expectRevert(Errors.MetadataProvider__HashInvalid.selector);
        vm.prank(address(registry));
        metadataProvider.setMetadata(ipId, v1Metadata);
    }

    /// @notice Tests metadata set without the right registration date reverts.
    function test_MetadataProvider_SetMetadata_Reverts_InvalidRegistrationDate() public {
        v1Metadata = abi.encode(
            IP.MetadataV1({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: uint64(0),
                registrant: alice,
                uri: IP_EXTERNAL_URL

            })
        );
        vm.expectRevert(Errors.MetadataProvider__RegistrationDateInvalid.selector);
        vm.prank(address(registry));
        metadataProvider.setMetadata(ipId, v1Metadata);
    }

    /// @notice Tests metadata set without a valid registrant reverts.
    function test_MetadataProvider_SetMetadata_Reverts_InvalidRegistrant() public {
        v1Metadata = abi.encode(
            IP.MetadataV1({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: uint64(block.timestamp),
                registrant: address(0),
                uri: IP_EXTERNAL_URL

            })
        );
        vm.expectRevert(Errors.MetadataProvider__RegistrantInvalid.selector);
        vm.prank(address(registry));
        metadataProvider.setMetadata(ipId, v1Metadata);
    }

    /// @notice Tests metadata set without a URI reverts.
    function test_MetadataProvider_SetMetadata_Reverts_InvalidURI() public {
        v1Metadata = abi.encode(
            IP.MetadataV1({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: uint64(block.timestamp),
                registrant: alice,
                uri: ""

            })
        );
        vm.expectRevert(Errors.MetadataProvider__URIInvalid.selector);
        vm.prank(address(registry));
        metadataProvider.setMetadata(ipId, v1Metadata);
    }

    /// @notice Checks that IP assets may be upgraded to the upgraded provider.
    function test_MetadataProvider_Upgrade() public {
        vm.prank(address(registry));
        metadataProvider.setMetadata(ipId, v1Metadata);
        vm.prank(address(registry));
        metadataProvider.setUpgradeProvider(address(upgradedProvider));
        bytes memory v2Metadata = abi.encode(
            ExpectedUpgradedMetadataV2({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: uint64(block.timestamp),
                registrant: alice,
                uri: IP_EXTERNAL_URL,
                nickname: IP_NICKNAME,
                decimals: IP_DECIMALS
            })
        );

        vm.prank(alice);
        metadataProvider.upgrade(payable(ipId), v2Metadata);
        assertEq(upgradedProvider.name(ipId), IP_NAME);
        assertEq(upgradedProvider.hash(ipId), IP_HASH);
        assertEq(upgradedProvider.registrationDate(ipId), uint64(block.timestamp));
        assertEq(upgradedProvider.registrant(ipId), alice);
        assertEq(upgradedProvider.uri(ipId), IP_EXTERNAL_URL);
        assertEq(upgradedProvider.nickname(ipId), IP_NICKNAME);
        assertEq(upgradedProvider.decimals(ipId), IP_DECIMALS);
    }

    /// @notice Checks that upgrades revert when a new provider is not yet set.
    function test_MetadataProvider_Upgrade_Reverts_UpgradeUnavailable() public {
        vm.expectRevert(Errors.MetadataProvider__UpgradeUnavailable.selector);
        metadataProvider.upgrade(payable(ipId), v1Metadata);
    }

    /// @notice Checks that upgrades revert when called by a non IP asset owner.
    function test_MetadataProvider_Upgrade_Reverts_OwnerInvalid() public {
        vm.prank(address(registry));
        metadataProvider.setUpgradeProvider(address(upgradedProvider));
        vm.expectRevert(Errors.MetadataProvider__IPAssetOwnerInvalid.selector);
        vm.prank(bob);
        metadataProvider.upgrade(payable(ipId), v1Metadata);
    }

    /// @notice Checks upgrades revert when new metadata is incompatible.
    /// TODO: Add parameterized testing to vet across a suite of variants.
    function test_MetadataProvider_Upgrade_Reverts_DataIncompatible() public {
        vm.prank(address(registry));
        metadataProvider.setUpgradeProvider(address(upgradedProvider));

        bytes memory v2Metadata = abi.encode(
            ExpectedUpgradedMetadataV2({
                name: IP_NAME,
                hash: IP_HASH,
                registrant: bob, // Incompatible: This was originally alice
                registrationDate: uint64(block.timestamp),
                uri: IP_EXTERNAL_URL,
                nickname: IP_NICKNAME,
                decimals: IP_DECIMALS
            })
        );
        vm.expectRevert(Errors.MetadataProvider__MetadataNotCompatible.selector);
        vm.prank(alice);
        metadataProvider.upgrade(payable(ipId), v2Metadata);
    }


    /// @notice Checks that metadata setting reverts if not called by the registry.
    function test_MetadataProvider_SetUpgradeProvider() public {
        vm.prank(address(registry));
        metadataProvider.setUpgradeProvider(address(upgradedProvider));
        assertEq(address(metadataProvider.upgradeProvider()), address(upgradedProvider));
    }

    /// @notice Checks that setting an invalid upgrade provider reverts.
    function test_MetadataProvider_SetUpgradeProvider_Reverts_ProviderInvalid() public {
        vm.expectRevert(Errors.MetadataProvider__UpgradeProviderInvalid.selector);
        vm.prank(address(registry));
        metadataProvider.setUpgradeProvider(address(0));
    }


    /// @notice Checks that metadata setting reverts if not called by the registry.
    function test_MetadataProvider_SetMetadata_Reverts_Unauthorized() public {
        vm.expectRevert(Errors.MetadataProvider__Unauthorized.selector);
        metadataProvider.setMetadata(ipId, "");
    }
}
