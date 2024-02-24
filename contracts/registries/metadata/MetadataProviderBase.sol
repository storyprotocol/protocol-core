// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IMetadataProvider } from "../../interfaces/registries/metadata/IMetadataProvider.sol";
import { IIPAssetRegistry } from "../../interfaces/registries/IIPAssetRegistry.sol";
import { IMetadataProviderMigratable } from "../../interfaces/registries/metadata/IMetadataProviderMigratable.sol";
import { Errors } from "../../lib/Errors.sol";

/// @title IP Metadata Provider Base Contract
/// @notice Metadata provider base contract for storing canonical IP metadata.
abstract contract MetadataProviderBase is IMetadataProviderMigratable {
    /// @notice Returns the protocol-wide IP asset registry.
    IIPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Returns the new metadata provider IP assets may migrate to.
    IMetadataProvider public upgradeProvider;

    /// @notice Maps IP assets (via their IP ID) to their canonical metadata.
    mapping(address ip => bytes metadata) internal _ipMetadata;

    /// @notice Restricts calls to only originate from a protocol-authorized caller.
    modifier onlyIPAssetRegistry() {
        if (msg.sender != address(IP_ASSET_REGISTRY)) {
            revert Errors.MetadataProvider__Unauthorized();
        }
        _;
    }

    constructor(address ipAssetRegistry) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(ipAssetRegistry);
    }

    /// @notice Gets the metadata associated with an IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return metadata The encoded metadata associated with the IP asset.
    function getMetadata(address ipId) external view virtual override returns (bytes memory) {
        return _ipMetadata[ipId];
    }

    /// @notice Sets a upgrade provider for users to migrate their metadata to.
    /// @param provider The address of the new metadata provider to migrate to.
    function setUpgradeProvider(address provider) external onlyIPAssetRegistry {
        if (provider == address(0)) {
            revert Errors.MetadataProvider__UpgradeProviderInvalid();
        }
        // TODO: We may want to add interface detection here if auth changes.
        upgradeProvider = IMetadataProviderMigratable(provider);
    }

    /// @notice Updates the provider used by the IP asset, migrating existing metadata to the new provider, and adding
    /// new metadata.
    /// @param ipId The address identifier of the IP asset.
    /// @param metadata Additional metadata in bytes used by the new metadata provider.
    function upgrade(address payable ipId, bytes memory metadata) external override {
        if (address(upgradeProvider) == address(0)) {
            revert Errors.MetadataProvider__UpgradeUnavailable();
        }
        // TODO: Provide more flexible IPAsset authorization via access controller.
        if (msg.sender != IIPAccount(ipId).owner()) {
            revert Errors.MetadataProvider__IPAssetOwnerInvalid();
        }
        if (!_compatible(_ipMetadata[ipId], metadata)) {
            revert Errors.MetadataProvider__MetadataNotCompatible();
        }
        IP_ASSET_REGISTRY.setMetadata(ipId, address(upgradeProvider), metadata);
    }

    /// @notice Sets the metadata associated with an IP asset.
    /// @dev Enforced to be only callable by the IP asset registry.
    /// @param ipId The address identifier of the IP asset.
    /// @param metadata The metadata in bytes to associate with the IP asset.
    function setMetadata(address ipId, bytes memory metadata) external virtual onlyIPAssetRegistry {
        _verifyMetadata(metadata);
        _ipMetadata[ipId] = metadata;
        emit MetadataSet(ipId, metadata);
    }

    /// @dev Checks that the data conforms to the canonical metadata standards.
    /// @param metadata The canonical metadata in bytes to verify.
    function _verifyMetadata(bytes memory metadata) internal virtual;

    /// @dev Checks whether two sets of metadata are compatible with one another.
    /// @param m1 The first set of bytes metadata being compared.
    /// @param m2 The second set of bytes metadata being compared.
    function _compatible(bytes memory m1, bytes memory m2) internal pure virtual returns (bool);
}
