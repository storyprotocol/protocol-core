// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title Metadata Provider Interface
interface IMetadataProvider {
    /// @notice Emits when canonical metadata was set for a specific IP asset.
    /// @param ipId The address of the IP asset.
    /// @param metadata The encoded metadata associated with the IP asset.
    event MetadataSet(address ipId, bytes metadata);

    /// @notice Gets the metadata associated with an IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return metadata The encoded metadata associated with the IP asset.
    function getMetadata(address ipId) external view returns (bytes memory);

    /// @notice Sets the metadata associated with an IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @param metadata The metadata in bytes to associate with the IP asset.
    function setMetadata(address ipId, bytes memory metadata) external;
}
