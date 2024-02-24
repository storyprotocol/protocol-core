// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";

import { IP } from "contracts/lib/IP.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

/// @title IP Asset Renderer Test Contract
/// @notice Tests IP asset rendering functionality.
/// TODO: Make this inherit module base to avoid code duplication.
contract IPAssetRendererTest is BaseTest {
    // Default IP asset attributes.
    string public constant IP_NAME = "IPAsset";
    string public constant IP_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant IP_HASH = "0x00";
    string public constant IP_EXTERNAL_URL = "https://storyprotocol.xyz";
    uint64 public IP_REGISTRATION_DATE;

    /// @notice Mock IP identifier for resolver testing.
    address public ipId;

    /// @notice Initializes the base token contract for testing.
    function setUp() public virtual override(BaseTest) {
        super.setUp();
        buildDeployMiscCondition(
            DeployMiscCondition({ ipAssetRenderer: true, ipMetadataProvider: false, ipResolver: true })
        );
        deployConditionally();
        postDeploymentSetup();

        IP_REGISTRATION_DATE = uint64(block.timestamp);

        vm.startPrank(alice);
        uint256 tokenId = mockNFT.mintId(alice, 99);
        bytes memory metadata = abi.encode(
            IP.MetadataV1({
                name: IP_NAME,
                hash: IP_HASH,
                registrationDate: IP_REGISTRATION_DATE,
                registrant: alice,
                uri: IP_EXTERNAL_URL
            })
        );
        ipId = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenId, address(ipResolver), true, metadata);
        vm.stopPrank();
    }

    /// @notice Tests that the constructor works as expected.
    function test_IPAssetRenderer_Constructor() public virtual {
        assertEq(address(ipAssetRenderer.IP_ASSET_REGISTRY()), address(ipAssetRegistry));
    }

    /// @notice Tests that ipAssetRenderer can properly resolve names.
    function test_IPAssetRenderer_Name() public virtual {
        assertEq(ipAssetRenderer.name(ipId), IP_NAME);
    }

    /// @notice Tests that the ipAssetRenderer can properly resolve descriptions.
    function test_IPAssetRenderer_Description() public virtual {
        assertEq(
            ipAssetRenderer.description(ipId),
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

    /// @notice Tests that ipAssetRenderer can properly resolve hashes.
    function test_IPAssetRenderer_Hash() public virtual {
        assertEq(ipAssetRenderer.hash(ipId), IP_HASH);
    }

    /// @notice Tests that ipAssetRenderer can properly resolve registration dates.
    function test_IPAssetRenderer_RegistrationDate() public virtual {
        assertEq(uint256(ipAssetRenderer.registrationDate(ipId)), uint256(IP_REGISTRATION_DATE));
    }

    /// @notice Tests that ipAssetRenderer can properly resolve registrants.
    function test_IPAssetRenderer_Registrant() public virtual {
        assertEq(ipAssetRenderer.registrant(ipId), alice);
    }

    /// @notice Tests that ipAssetRenderer can properly resolve URLs.
    function test_IPAssetRenderer_ExternalURL() public virtual {
        assertEq(ipAssetRenderer.uri(ipId), IP_EXTERNAL_URL);
    }

    /// @notice Tests that ipAssetRenderer can properly owners.
    function test_IPAssetRenderer_Owner() public virtual {
        assertEq(ipAssetRenderer.owner(ipId), alice);
    }

    /// @notice Tests that the ipAssetRenderer can get the right token URI.
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
        assertEq(expectedURI, ipAssetRenderer.tokenURI(ipId));
    }
}
