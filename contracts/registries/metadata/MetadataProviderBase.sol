// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IP } from "contracts/lib/IP.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IMetadataProvider } from "contracts/interfaces/registries/metadata/IMetadataProvider.sol";
import { IMetadataProviderMigratable } from "contracts/interfaces/registries/metadata/IMetadataProviderMigratable.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";

/// @title IP Metadata Provider Base Contract
/// @notice Metadata provider base contract for storing canonical IP metadata.
abstract contract MetadataProviderBase is IMetadataProviderMigratable {

    /// @notice Gets the protocol-wide IP asset registry.
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Returns the new metadata provider users may migrate to.
    IMetadataProvider public upgradeProvider;

    /// @notice Maps IP assets (via their IP ID) to their canonical metadata.
    mapping(address ip => bytes metadata) internal _ipMetadata;

    /// @notice Restricts calls to only originate from a protocol-authorized caller.
    modifier onlyIPAssetRegistry {
        if (msg.sender != address(IP_ASSET_REGISTRY)) {
            revert Errors.MetadataProvider__Unauthorized();
        }
        _;
    }

    /// @notice Initializes the metadata provider contract.
    /// @param ipAssetRegistry The protocol-wide IP asset registry.
    constructor(address ipAssetRegistry) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
    }

    /// @notice Gets the IP metadata associated with an IP asset based on its IP ID.
    /// @param ipId The IP id of the target IP asset.
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

    /// @notice Upgrades the metadata provider of an IP asset.
    /// @param ipId The IP id of the target IP asset.
    /// @param metadata The existing metadata paired with new metadata to add.
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

    /// @notice Sets the IP metadata associated with an IP asset based on its IP ID.
    /// @param ipId The IP id of the IP asset to set metadata for.
    /// @param data The metadata in bytes to set for the IP asset.
    function setMetadata(address ipId, bytes memory data) external virtual onlyIPAssetRegistry {
        _verifyMetadata(data);
        _ipMetadata[ipId] = data;
        emit MetadataSet(ipId, data);
    }

    /// @dev Checks that the data conforms to the canonical metadata standards.
    /// @param data The canonical metadata in bytes to verify.
    function _verifyMetadata(bytes memory data) internal virtual;

    /// @dev Checks whether two sets of metadata are compatible with one another.
    /// @param m1 The first set of bytes metadata being compared.
    /// @param m2 The second set of bytes metadata being compared.
    function _compatible(bytes memory m1, bytes memory m2) internal virtual pure returns (bool);
}
