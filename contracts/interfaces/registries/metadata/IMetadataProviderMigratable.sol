// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IMetadataProvider } from "./IMetadataProvider.sol";
import { IIPAssetRegistry } from "../IIPAssetRegistry.sol";

/// @title Metadata Provider Interface
interface IMetadataProviderMigratable is IMetadataProvider {
    /// @notice Returns the protocol-wide IP asset registry.
    function IP_ASSET_REGISTRY() external view returns (IIPAssetRegistry);

    /// @notice Returns the new metadata provider IP assets may migrate to.
    function upgradeProvider() external returns (IMetadataProvider);

    /// @notice Sets a upgrade provider for users to migrate their metadata to.
    /// @param provider The address of the new metadata provider to migrate to.
    function setUpgradeProvider(address provider) external;

    /// @notice Updates the provider used by the IP asset, migrating existing metadata to the new provider, and adding
    /// new metadata.
    /// @param ipId The address identifier of the IP asset.
    /// @param extraMetadata Additional metadata in bytes used by the new metadata provider.
    function upgrade(address payable ipId, bytes memory extraMetadata) external;
}
