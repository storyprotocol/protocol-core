// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { IP } from "../../lib/IP.sol";
import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IPAssetRegistry } from "../../registries/IPAssetRegistry.sol";
import { IMetadataProvider } from "../../interfaces/registries/metadata/IMetadataProvider.sol";
import { LicenseRegistry } from "../../registries/LicenseRegistry.sol";
import { RoyaltyModule } from "../../modules/royalty/RoyaltyModule.sol";

/// @title IP Asset Renderer
/// @notice The IP asset renderer is responsible for rendering canonical
///         metadata associated with each IP asset. This includes generation
///         of attributes, on-chain SVGs, and external URLs. Note that the
///         underlying data being rendered is strictly immutable.
contract IPAssetRenderer {
    /// @notice The global IP asset registry.
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice The global licensing registry.
    LicenseRegistry public immutable LICENSE_REGISTRY;

    // Modules storing attribution related to IPs.
    RoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice Initializes the IP asset renderer.
    /// TODO: Add different customization options - e.g. font, colorways, etc.
    /// TODO: Add an external URL for generating SP-branded links for each IP.
    constructor(address assetRegistry, address licenseRegistry, address royaltyModule) {
        IP_ASSET_REGISTRY = IPAssetRegistry(assetRegistry);
        LICENSE_REGISTRY = LicenseRegistry(licenseRegistry);
        ROYALTY_MODULE = RoyaltyModule(royaltyModule);
    }

    // TODO: Add contract URI support for metadata about the entire IP registry.

    // TODO: Add rendering functions around licensing information.

    // TODO: Add rendering functions around royalties information.

    // TODO: Add rendering functions around tagging information.

    /// @notice Fetches the canonical name associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    function name(address ipId) external view returns (string memory) {
        IP.MetadataV1 memory metadata = _metadata(ipId);
        return metadata.name;
    }

    /// @notice Fetches the canonical description associated with the IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @return The string descriptor of the IP.
    /// TODO: Add more information related to licensing or royalties.
    /// TODO: Update the description to an SP base URL if external URL not set.
    function description(address ipId) public view returns (string memory) {
        IP.MetadataV1 memory metadata = _metadata(ipId);
        return
            string.concat(
                metadata.name,
                ", IP #",
                Strings.toHexString(ipId),
                ", is currently owned by",
                Strings.toHexString(owner(ipId)),
                ". To learn more about this IP, visit ",
                metadata.uri
            );
    }

    /// @notice Fetches the keccak-256 content hash associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @return The bytes32 content hash of the IP.
    function hash(address ipId) external view returns (bytes32) {
        IP.MetadataV1 memory metadata = _metadata(ipId);
        return metadata.hash;
    }

    /// @notice Fetches the date of registration of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function registrationDate(address ipId) external view returns (uint64) {
        IP.MetadataV1 memory metadata = _metadata(ipId);
        return metadata.registrationDate;
    }

    /// @notice Fetches the initial registrant of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function registrant(address ipId) external view returns (address) {
        IP.MetadataV1 memory metadata = _metadata(ipId);
        return metadata.registrant;
    }

    /// @notice Fetches the external URL associated with the IP.
    /// @param ipId The canonical ID of the specified IP.
    function uri(address ipId) external view returns (string memory) {
        IP.MetadataV1 memory metadata = _metadata(ipId);
        return metadata.uri;
    }

    /// @notice Fetches the current owner of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function owner(address ipId) public view returns (address) {
        return IIPAccount(payable(ipId)).owner();
    }

    /// @notice Generates a JSON of all metadata attribution related to the IP.
    /// TODO: Make this ERC-721 compatible, so that the IP registry may act as
    ///       an account-bound ERC-721 that points to this function for metadata.
    /// TODO: Add SVG support.
    /// TODO: Add licensing, royalties, and tagging information support.
    function tokenURI(address ipId) external view returns (string memory) {
        IP.MetadataV1 memory metadata = _metadata(ipId);
        string memory baseJson = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"name": "IP Asset #',
                Strings.toHexString(ipId),
                '", "description": "',
                description(ipId),
                '", "attributes": ['
            )
            /* solhint-enable */
        );

        string memory ipAttributes = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"trait_type": "Name", "value": "',
                metadata.name,
                '"},'
                '{"trait_type": "Owner", "value": "',
                Strings.toHexString(owner(ipId)),
                '"},'
                '{"trait_type": "Registrant", "value": "',
                Strings.toHexString(uint160(metadata.registrant), 20),
                '"},',
                '{"trait_type": "Hash", "value": "',
                Strings.toHexString(uint256(metadata.hash), 32),
                '"},',
                '{"trait_type": "Registration Date", "value": "',
                Strings.toString(metadata.registrationDate),
                '"}'
            )
            /* solhint-enable */
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(string(abi.encodePacked(baseJson, ipAttributes, "]}"))))
                )
            );
    }

    /// TODO: Add SVG generation support for branding within token metadata.

    /// @dev Internal function for fetching the metadata tied to an IP record.
    function _metadata(address ipId) internal view returns (IP.MetadataV1 memory metadata) {
        IMetadataProvider provider = IMetadataProvider(IP_ASSET_REGISTRY.metadataProvider(ipId));
        bytes memory data = provider.getMetadata(ipId);
        if (data.length != 0) {
            metadata = abi.decode(data, (IP.MetadataV1));
        }
    }
}
