// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { AccessController } from "contracts/AccessController.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { ERC6551Registry } from "@erc6551/ERC6551Registry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { MetadataProviderV1 } from "contracts/registries/metadata/MetadataProviderV1.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { IP } from "contracts/lib/IP.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";

/// @title IP Asset Renderer Test Contract
/// @notice Tests IP asset rendering functionality.
/// TODO: Make this inherit module base to avoid code duplication.
contract IPAssetRendererTest is BaseTest {
    // Module placeholders
    // TODO: Mock these out.
    address public taggingModule = vm.addr(0x1111);

    /// @notice Gets the metadata provider used for IP registration.
    MetadataProviderV1 public metadataProvider;

    /// @notice Used for registration in the IP asset registry.
    RegistrationModule public registrationModule;

    /// @notice Gets the protocol-wide license registry.
    LicenseRegistry public licenseRegistry;

    /// @notice Gets the protocol-wide IP asset registry.
    IPAssetRegistry public ipAssetRegistry;

    /// @notice Gets the protocol-wide module registry.
    ModuleRegistry public moduleRegistry;

    /// @notice Gets the protocol-wide IP account registry.
    IPAccountRegistry public ipAccountRegistry;

    // Default IP asset attributes.
    string public constant IP_NAME = "IPAsset";
    string public constant IP_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant IP_HASH = "0x00";
    string public constant IP_EXTERNAL_URL = "https://storyprotocol.xyz";
    uint64 public IP_REGISTRATION_DATE;

    /// @notice The access controller address.
    AccessController public accessController;

    /// @notice The token contract SUT.
    IPAssetRenderer public renderer;

    /// @notice The IP resolver.
    IPResolver public resolver;

    /// @notice Mock IP identifier for resolver testing.
    address public ipId;

    Governance public governance;

    LicensingModule public licensingModule;

    /// @notice Initializes the base token contract for testing.
    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();
        IP_REGISTRATION_DATE = uint64(block.timestamp);
        governance = new Governance(address(this));

        // TODO: Create an IP asset registry mock instead.
        // TODO: Create an IP record registry mock instead.
        accessController = new AccessController(address(governance));
        moduleRegistry = new ModuleRegistry(address(governance));
        MockERC721 erc721 = new MockERC721("MockERC721");

        ERC6551Registry erc6551Registry = new ERC6551Registry();
        IPAccountImpl ipAccountImpl = new IPAccountImpl();
        ipAccountRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(ipAccountImpl)
        );
        ipAssetRegistry = new IPAssetRegistry(
            address(accessController),
            address(erc6551Registry),
            address(ipAccountImpl),
            address(moduleRegistry)
        );
        RoyaltyModule royaltyModule = new RoyaltyModule(address(governance));
        licenseRegistry = new LicenseRegistry();
        licensingModule = new LicensingModule(
            address(accessController),
            address(ipAssetRegistry),
            address(royaltyModule),
            address(licenseRegistry)
        );
        licenseRegistry.setLicensingModule(address(licensingModule));
        resolver = new IPResolver(address(accessController), address(ipAssetRegistry));
        renderer = new IPAssetRenderer(
            address(ipAssetRegistry),
            address(licenseRegistry),
            taggingModule,
            address(royaltyModule)
        );
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipAssetRegistry),
            address(licensingModule),
            address(resolver)
        );
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
        royaltyModule.setLicensingModule(address(licensingModule));

        vm.prank(alice);
        uint256 tokenId = erc721.mintId(alice, 99);
        bytes memory metadata = abi.encode(
            IP.MetadataV1({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: IP_REGISTRATION_DATE,
                registrant: alice,
                uri: IP_EXTERNAL_URL
            })
        );
        vm.prank(alice);
        ipId = ipAssetRegistry.register(
            block.chainid,
            address(erc721),
            tokenId,
            address(resolver),
            true,
            metadata
        );
    }

    /// @notice Tests that the constructor works as expected.
    function test_IPAssetRenderer_Constructor() public virtual {
        assertEq(address(renderer.IP_ASSET_REGISTRY()), address(ipAssetRegistry));
    }

    /// @notice Tests that renderer can properly resolve names.
    function test_IPAssetRenderer_Name() public virtual {
        assertEq(renderer.name(ipId), IP_NAME);
    }

    /// @notice Tests that the renderer can properly resolve descriptions.
    function test_IPAssetRenderer_Description() public virtual {
        assertEq(
            renderer.description(ipId),
            string.concat(
                IP_NAME,
                ", IP #",
                Strings.toHexString(ipId),
                ", is currently owned by",
                Strings.toHexString(alice),
                ". To learn more about this IP, visit ",
                IP_EXTERNAL_URL
            )
        );
    }

    /// @notice Tests that renderer can properly resolve hashes.
    function test_IPAssetRenderer_Hash() public virtual {
        assertEq(renderer.hash(ipId), IP_HASH);
    }

    /// @notice Tests that renderer can properly resolve registration dates.
    function test_IPAssetRenderer_RegistrationDate() public virtual {
        assertEq(uint256(renderer.registrationDate(ipId)), uint256(IP_REGISTRATION_DATE));
    }

    /// @notice Tests that renderer can properly resolve registrants.
    function test_IPAssetRenderer_Registrant() public virtual {
        assertEq(renderer.registrant(ipId), alice);
    }

    /// @notice Tests that renderer can properly resolve URLs.
    function test_IPAssetRenderer_ExternalURL() public virtual {
        assertEq(renderer.uri(ipId), IP_EXTERNAL_URL);
    }

    /// @notice Tests that renderer can properly owners.
    function test_IPAssetRenderer_Owner() public virtual {
        assertEq(renderer.owner(ipId), alice);
    }

    /// @notice Tests that the renderer can get the right token URI.
    function test_IPAssetRenderer_TokenURI() public virtual {
        string memory ownerStr = Strings.toHexString(uint160(address(alice)));
        string memory description = string.concat(
            IP_NAME,
            ", IP #",
            Strings.toHexString(ipId),
            ", is currently owned by",
            Strings.toHexString(alice),
            ". To learn more about this IP, visit ",
            IP_EXTERNAL_URL
        );

        string memory ipIdStr = Strings.toHexString(uint160(ipId));
        /* solhint-disable */
        string memory uriEncoding = string(
            abi.encodePacked(
                '{"name": "IP Asset #',
                ipIdStr,
                '", "description": "',
                description,
                '", "attributes": [',
                '{"trait_type": "Name", "value": "IPAsset"},',
                '{"trait_type": "Owner", "value": "',
                ownerStr,
                '"},'
                '{"trait_type": "Registrant", "value": "',
                ownerStr,
                '"},',
                '{"trait_type": "Hash", "value": "0x3078303000000000000000000000000000000000000000000000000000000000"},',
                '{"trait_type": "Registration Date", "value": "',
                Strings.toString(IP_REGISTRATION_DATE),
                '"}',
                "]}"
            )
        );
        /* solhint-enable */
        string memory expectedURI = string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(string(abi.encodePacked(uriEncoding))))
            )
        );
        assertEq(expectedURI, renderer.tokenURI(ipId));
    }
}
