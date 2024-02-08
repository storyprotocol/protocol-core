// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IMetadataProvider } from "./IMetadataProvider.sol";

/// @title Metadata Provider Interface
interface IMetadataProviderMigratable is IMetadataProvider {
    /// @notice Returns the new metadata provider IP assets may migrate to.
    /// @return Address of the new metadata provider if set, else the zero address.
    function upgradeProvider() external returns (IMetadataProvider);

    /// @notice Sets a new metadata provider that IP assets may migrate to.
    /// @param provider The address of the new metadata provider.
    function setUpgradeProvider(address provider) external;

    /// @notice Updates the provider used by the IP asset, migrating existing
    ///         metadata to the new provider, and adding new metadata.
    /// @param ipId The address identifier of the IP asset.
    /// @param extraMetadata Additional metadata used by the new metadata provider.
    function upgrade(address payable ipId, bytes memory extraMetadata) external;
}
