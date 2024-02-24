// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IMetadataProvider } from "../../interfaces/registries/metadata/IMetadataProvider.sol";
import { IModuleRegistry } from "../../interfaces/registries/IModuleRegistry.sol";

/// @title IP Metadata Provider Contract
/// @notice Base contract used for customization of canonical IP metadata.
contract IPMetadataProvider is IMetadataProvider {
    /// @notice Gets the protocol-wide module registry.
    IModuleRegistry public immutable MODULE_REGISTRY;

    /// @notice Maps IPs to their metadata based on their IP IDs.
    mapping(address ip => bytes metadata) internal _ipMetadata;

    constructor(address moduleRegistry) {
        MODULE_REGISTRY = IModuleRegistry(moduleRegistry);
    }

    /// @notice Gets the metadata associated with an IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return metadata The encoded metadata associated with the IP asset.
    function getMetadata(address ipId) external view virtual override returns (bytes memory) {
        return _ipMetadata[ipId];
    }

    // TODO: Add access control for IP owner can set metadata.
    /// @notice Sets the metadata associated with an IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @param metadata The metadata in bytes to associate with the IP asset.
    function setMetadata(address ipId, bytes memory metadata) external {
        _ipMetadata[ipId] = metadata;
    }
}
