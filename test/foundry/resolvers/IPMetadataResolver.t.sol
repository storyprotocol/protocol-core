// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

import { ResolverBaseTest } from "test/foundry/resolvers/ResolverBase.t.sol";
import { IPMetadataResolver } from "contracts/resolvers/IPMetadataResolver.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { IIPMetadataResolver } from "contracts/interfaces/resolvers/IIPMetadataResolver.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { ModuleBaseTest } from "test/foundry/modules/ModuleBase.t.sol";
import { IP } from "contracts/lib/IP.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { METADATA_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";

/// @title IP Metadata Resolver Test Contract
/// @notice Tests IP metadata resolver functionality.
contract IPMetadataResolverTest is ResolverBaseTest {

    // Default IP record attributes.
    string public constant RECORD_NAME = "IPRecord";
    string public constant RECORD_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant RECORD_HASH = "";
    uint64 public constant RECORD_REGISTRATION_DATE = 999999;
    string public constant RECORD_URI = "https://storyprotocol.xyz";

    /// @notice The registration module.
    address public registrationModule;

    /// @notice The token contract SUT.
    IIPMetadataResolver public ipResolver;

    /// @notice Mock IP identifier for resolver testing.
    address public ipId;

    /// @notice Initializes the base token contract for testing.
    function setUp() public virtual override(ResolverBaseTest) {
        ResolverBaseTest.setUp();
        MockERC721 erc721 = new MockERC721();
        vm.prank(alice);
        ipResolver = IIPMetadataResolver(_deployModule());
        uint256 tokenId = erc721.mintId(alice, 99);
        // TODO: Mock this correctly
        registrationModule = address(new RegistrationModule(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry),
            address(ipResolver)
        ));
        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, registrationModule);
        moduleRegistry.registerModule(METADATA_RESOLVER_MODULE_KEY, address(ipResolver));
        vm.prank(registrationModule);
        ipId = ipRecordRegistry.register(
            block.chainid,
            address(erc721),
            tokenId,
            address(ipResolver),
            true
        );
    }

    /// @notice Tests that the IP resolver interface is supported.
    function test_IPMetadataResolver_SupportsInterface() public virtual {
        assertTrue(ipResolver.supportsInterface(type(IIPMetadataResolver).interfaceId));
    }

    /// @notice Tests that metadata may be properly set for the resolver.
    function test_IPMetadataResolver_SetMetadata() public {
        vm.prank(ipId);
        accessController.setPermission(ipId, alice, address(ipResolver), IIPMetadataResolver.setMetadata.selector, 1);
        vm.prank(alice);
        ipResolver.setMetadata(
            ipId,
            IP.MetadataRecord({
                name: RECORD_NAME,
                description: RECORD_DESCRIPTION,
                hash: RECORD_HASH,
                registrationDate: RECORD_REGISTRATION_DATE,
                registrant: alice,
                uri: RECORD_URI
            })
        );
        assertEq(ipResolver.name(ipId), RECORD_NAME);
        assertEq(ipResolver.description(ipId), RECORD_DESCRIPTION);
        assertEq(ipResolver.hash(ipId), RECORD_HASH);
        assertEq(ipResolver.registrationDate(ipId), RECORD_REGISTRATION_DATE);
        assertEq(ipResolver.registrant(ipId), alice);
        assertEq(ipResolver.owner(ipId), alice);
        assertEq(ipResolver.uri(ipId), RECORD_URI);

        // Also check the metadata getter returns as expected.
        IP.Metadata memory metadata = ipResolver.metadata(ipId);
        assertEq(metadata.name, RECORD_NAME);
        assertEq(metadata.description, RECORD_DESCRIPTION);
        assertEq(metadata.hash, RECORD_HASH);
        assertEq(metadata.registrationDate, RECORD_REGISTRATION_DATE);
        assertEq(metadata.registrant, alice);
        assertEq(metadata.uri, RECORD_URI);
        assertEq(metadata.owner, alice);
    }

    /// @notice Checks that an unauthorized call to setMetadata reverts.
    function test_IPMetadataResolver_SetMetadata_Reverts_Unauthorized() public {
        vm.expectRevert(Errors.Module_Unauthorized.selector);
        ipResolver.setMetadata(
            ipId,
            IP.MetadataRecord({
                name: RECORD_NAME,
                description: RECORD_DESCRIPTION,
                hash: RECORD_HASH,
                registrationDate: RECORD_REGISTRATION_DATE,
                registrant: alice,
                uri: RECORD_URI
            })
        );
    }

    /// @notice Tests that the name may be properly set for the resolver.
    function test_IPMetadataResolver_SetName() public {
        vm.prank(ipId);
        accessController.setPermission(ipId, alice, address(ipResolver), IIPMetadataResolver.setName.selector, 1);
        vm.prank(alice);
        ipResolver.setName(ipId, RECORD_NAME);
        assertEq(RECORD_NAME, ipResolver.name(ipId));
    }

    /// @notice Checks that an unauthorized call to setName reverts.
    function test_IPMetadataResolver_SetName_Reverts_Unauthorized() public {
        vm.expectRevert(Errors.Module_Unauthorized.selector);
        ipResolver.setName(ipId, RECORD_NAME);
    }

    /// @notice Tests that the description may be properly set for the resolver.
    function test_IPMetadataResolver_SetDescriptionx() public {
        vm.prank(ipId);
        accessController.setPermission(ipId, alice, address(ipResolver), IIPMetadataResolver.setDescription.selector, 1);
        vm.prank(alice);
        ipResolver.setDescription(ipId, RECORD_DESCRIPTION);
        assertEq(RECORD_DESCRIPTION, ipResolver.description(ipId));
    }

    /// @notice Checks that an unauthorized call to setDescription reverts.
    function test_IPMetadataResolver_SetDescription_Reverts_Unauthorized() public {
        vm.expectRevert(Errors.Module_Unauthorized.selector);
        ipResolver.setDescription(ipId, RECORD_DESCRIPTION);
    }

    /// @notice Tests that the hash may be properly set for the resolver.
    function test_IPMetadataResolver_SetHash() public {
        vm.prank(ipId);
        accessController.setPermission(ipId, alice, address(ipResolver), IIPMetadataResolver.setHash.selector, 1);
        vm.prank(alice);
        ipResolver.setHash(ipId, RECORD_HASH);
        assertEq(RECORD_HASH, ipResolver.hash(ipId));
    }

    /// @notice Checks that an unauthorized call to setHash reverts.
    function test_IPMetadataResolver_SetHash_Reverts_Unauthorized() public {
        vm.expectRevert(Errors.Module_Unauthorized.selector);
        ipResolver.setHash(ipId, RECORD_HASH);
    }

    /// @notice Checks that owner queries return the zero address if there is no
    ///         IP account attached to the IP or if it was not registered.
    function test_IPMetadataResolver_Owner_NonExistent() public {
        // TODO: Make more granular testing for the above two conditions.
        assertEq(address(0), ipResolver.owner(address(0)));
    }

    /// @notice Checks setting token URI works as expected.
    function test_IPMetadataResolver_SetTokenURI() public {
        vm.prank(ipId);
        accessController.setPermission(ipId, alice, address(ipResolver), IIPMetadataResolver.setURI.selector, 1);
        vm.prank(alice);
        ipResolver.setURI(ipId, RECORD_URI);
        assertEq(ipResolver.uri(ipId), RECORD_URI);
    }

    /// @notice Checks the default token URI renders as expected.
    function test_IPMetadataResolver_TokenURI_DefaultRender() public {
        // Check default empty string value for unregistered IP.
        assertEq(ipResolver.uri(address(0)), "");

        // Check default string value for registered IP.
        assertTrue(accessController.checkPermission(ipId, alice, address(ipResolver), IIPMetadataResolver.setMetadata.selector));
        vm.prank(alice);
        ipResolver.setMetadata(
            ipId,
            IP.MetadataRecord({
                name: RECORD_NAME,
                description: RECORD_DESCRIPTION,
                hash: RECORD_HASH,
                registrationDate: RECORD_REGISTRATION_DATE,
                registrant: alice,
                uri: "" // Blank indicates the default record should be used.
            })
        );
        string memory ownerStr = Strings.toHexString(uint160(address(alice)));
        string memory ipIdStr = Strings.toHexString(uint160(ipId));
        string memory uriEncoding = string(abi.encodePacked(
            '{"name": "IP Asset #', ipIdStr, '", "description": "IPs all the way down.", "attributes": [',
            '{"trait_type": "Name", "value": "IPRecord"},',
            '{"trait_type": "Owner", "value": "', ownerStr, '"},'
            '{"trait_type": "Registrant", "value": "', ownerStr, '"},',
            '{"trait_type": "Hash", "value": "0x0000000000000000000000000000000000000000000000000000000000000000"},',
            '{"trait_type": "Registration Date", "value": "', Strings.toString(RECORD_REGISTRATION_DATE), '"}',
            ']}'
        ));
        string memory expectedURI = string(abi.encodePacked(
            "data:application/json;base64,",
            Base64.encode(bytes(string(abi.encodePacked(uriEncoding))))
        ));
        assertEq(expectedURI, ipResolver.uri(ipId));
    }

    /// @dev Gets the expected name for the module.
    function _expectedName() internal virtual view override returns (string memory) {
        return "METADATA_RESOLVER_MODULE";
    }

    /// @dev Deploys a new IP Metadata Resolver.
    function _deployModule() internal override returns (address) {
        return address(
            new IPMetadataResolver(
                address(accessController),
                address(ipRecordRegistry),
                address(ipAccountRegistry),
                address(licenseRegistry)
            )
        );
    }

}
