// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

import { ResolverBaseTest } from "test/foundry/resolvers/ResolverBase.t.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { AccessController } from "contracts/AccessController.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { ModuleBaseTest } from "test/foundry/modules/ModuleBase.t.sol";
import { IP } from "contracts/lib/IP.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { Governance } from "contracts/governance/Governance.sol";

/// @title IP Asset Renderer Test Contract
/// @notice Tests IP asset rendering functionality.
/// TODO: Make this inherit module base to avoid code duplication.
contract IPAssetRendererTest is BaseTest {

    // Module placeholders
    // TODO: Mock these out.
    address taggingModule = vm.addr(0x1111);
    address royaltyModule = vm.addr(0x2222);

    /// @notice Gets the metadata provider used for IP registration.
    IPMetadataProvider metadataProvider;

    /// @notice Used for registration in the IP record registry.
    RegistrationModule public registrationModule;

    /// @notice Gets the protocol-wide license registry.
    LicenseRegistry public licenseRegistry;

    /// @notice Gets the protocol-wide IP record registry.
    IPRecordRegistry public ipRecordRegistry;

    /// @notice Gets the protocol-wide module registry.
    ModuleRegistry public moduleRegistry;

    /// @notice Gets the protocol-wide IP account registry.
    IPAccountRegistry public ipAccountRegistry;

    // Default IP record attributes.
    string public constant IP_NAME = "IPRecord";
    string public constant IP_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant IP_HASH = "";
    string public constant IP_EXTERNAL_URL = "https://storyprotocol.xyz";
    uint64 public constant IP_REGISTRATION_DATE = uint64(99);

    /// @notice The access controller address.
    AccessController public accessController;

    /// @notice The token contract SUT.
    IPAssetRenderer public renderer;

    /// @notice The IP resolver.
    IPResolver public resolver;

    /// @notice Mock IP identifier for resolver testing.
    address public ipId;

    Governance public governance;

    /// @notice Initializes the base token contract for testing.
    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();
        governance = new Governance(address(this));
        // TODO: Create an IP record registry mock instead.
        licenseRegistry = new LicenseRegistry("");
        accessController = new AccessController(address(governance));
        moduleRegistry = new ModuleRegistry(address(governance));
        MockERC721 erc721 = new MockERC721();
        ipAccountRegistry = new IPAccountRegistry(
            address(new ERC6551Registry()),
            address(accessController),
            address(new IPAccountImpl())
        );
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
        ipRecordRegistry = new IPRecordRegistry(
            address(moduleRegistry),
            address(ipAccountRegistry)
        );

        vm.prank(alice);
        uint256 tokenId = erc721.mintId(alice, 99);

        metadataProvider = new IPMetadataProvider(address(moduleRegistry));
        resolver = new IPResolver(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry)
        );

        // TODO: Mock out the registration module and module registry.
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry),
            address(metadataProvider),
            address(resolver)
        );
        renderer = new IPAssetRenderer(
            address(ipRecordRegistry),
            address(licenseRegistry),
            taggingModule,
            royaltyModule
        );
        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        vm.prank(address(registrationModule));
        ipId = ipRecordRegistry.register(
            block.chainid,
            address(erc721),
            tokenId,
            address(resolver),
            true,
            address(metadataProvider)
        );

        bytes memory metadata = abi.encode(
            IP.Metadata({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: IP_REGISTRATION_DATE,
                registrant: alice,
                uri: IP_EXTERNAL_URL

            })
        );
        vm.prank(address(registrationModule));
        metadataProvider.setMetadata(ipId, metadata);
    }

    /// @notice Tests that the constructor works as expected.
    function test_IPAssetRenderer_Constructor() public virtual {
        assertEq(address(renderer.IP_RECORD_REGISTRY()), address(ipRecordRegistry));
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
        string memory uriEncoding = string(abi.encodePacked(
            '{"name": "IP Asset #', ipIdStr, '", "description": "', description, '", "attributes": [',
            '{"trait_type": "Name", "value": "IPRecord"},',
            '{"trait_type": "Owner", "value": "', ownerStr, '"},'
            '{"trait_type": "Registrant", "value": "', ownerStr, '"},',
            '{"trait_type": "Hash", "value": "0x0000000000000000000000000000000000000000000000000000000000000000"},',
            '{"trait_type": "Registration Date", "value": "', Strings.toString(IP_REGISTRATION_DATE), '"}',
            ']}'
        ));
        string memory expectedURI = string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(string(abi.encodePacked(uriEncoding))))
        ));
        assertEq(expectedURI, renderer.tokenURI(ipId));
    }

}
