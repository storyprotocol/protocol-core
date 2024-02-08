// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { REGISTRATION_MODULE_KEY } from "../../lib/modules/Module.sol";
import { IMetadataProvider } from "../../interfaces/registries/metadata/IMetadataProvider.sol";
import { IModuleRegistry } from "../../interfaces/registries/IModuleRegistry.sol";
import { Errors } from "../../lib/Errors.sol";

/// @title IP Metadata Provider Contract
/// @notice Base contract used for customization of canonical IP metadata.
contract IPMetadataProvider is IMetadataProvider {
    /// @notice Gets the protocol-wide module registry.
    IModuleRegistry public immutable MODULE_REGISTRY;

    /// @notice Maps IPs to their metadata based on their IP IDs.
    mapping(address ip => bytes metadata) internal _ipMetadata;

    /// @notice Initializes the metadata provider contract.
    /// @param moduleRegistry Gets the protocol-wide module registry.
    constructor(address moduleRegistry) {
        MODULE_REGISTRY = IModuleRegistry(moduleRegistry);
    }

    /// @notice Gets the IP metadata associated with an IP asset based on its IP ID.
    /// @param ipId The IP id of the target IP asset.
    function getMetadata(address ipId) external view virtual override returns (bytes memory) {
        return _ipMetadata[ipId];
    }

    /// @notice Sets the IP metadata associated with an IP asset based on its IP ID.
    /// @param ipId The IP id of the IP asset to set metadata for.
    /// @param metadata The metadata in bytes to set for the IP asset.
    // TODO: Add access control for IP owner can set metadata.
    function setMetadata(address ipId, bytes memory metadata) external {
        _ipMetadata[ipId] = metadata;
    }
}
