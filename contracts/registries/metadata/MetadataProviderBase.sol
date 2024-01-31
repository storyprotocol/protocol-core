// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IP } from "contracts/lib/IP.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IMetadataProvider } from "contracts/interfaces/registries/metadata/IMetadataProvider.sol";
import { IMetadataProviderUpgradeable } from "contracts/interfaces/registries/metadata/IMetadataProviderUpgradeable.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IP Metadata Provider Base Contract
/// @notice Metadata provider base contract for storing canonical IP metadata.
abstract contract MetadataProviderBase is IMetadataProviderUpgradeable {

    /// @notice Gets the protocol-wide IP asset registry.
    address public immutable IP_ASSET_REGISTRY;

    /// @notice Returns the new metadata provider users may migrate to.
    IMetadataProvider public upgradeProvider;

    /// @notice The owner of the metadata provider (Story Protocol gov timelock).
    address public owner;

    /// @notice Maps IP assets (via their IP ID) to their canonical metadata.
    mapping(address ip => bytes metadata) internal _ipMetadata;

    /// @notice Restricts calls to only come from the owner.
    modifier onlyOwner {
        if (msg.sender != owner) {
            revert Errors.MetadataProvider__Unauthorized();
        }
        _;
    }

    /// @notice Restricts calls to only originate from a protocol-authorized caller.
    modifier onlyIPAssetRegistry {
        if (msg.sender != IP_ASSET_REGISTRY) {
            revert Errors.MetadataProvider__Unauthorized();
        }
        _;
    }

    /// @notice Initializes the metadata provider contract.
    /// @param ipAssetRegistry The protocol-wide IP asset registry.
    constructor(address ipAssetRegistry) {
        IP_ASSET_REGISTRY = ipAssetRegistry;
    }

    /// @notice Gets the IP metadata associated with an IP asset based on its IP ID.
    /// @param ipId The IP id of the target IP asset.
    function getMetadata(address ipId) external view virtual override returns (bytes memory) {
        return _ipMetadata[ipId];
    }

    /// @notice Sets a upgrade provider for users to migrate their metadata to.
    /// @param provider The address of the new metadata provider to migrate to.
    function setUpgradeProvider(address provider) external onlyIPAssetRegistry {
        upgradeProvider = IMetadataProviderUpgradeable(provider);
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
        upgradeProvider.setMetadata(ipId, metadata);
    }

    /// @notice Sets the IP metadata associated with an IP asset based on its IP ID.
    /// @param ipId The IP id of the IP asset to set metadata for.
    /// @param data The metadata in bytes to set for the IP asset.
    function setMetadata(address ipId, bytes memory data) external virtual onlyIPAssetRegistry {
        _ipMetadata[ipId] = data;
        emit MetadataSet(ipId, data);
    }

    /// @dev Checks whether two sets of metadata are compatible with one another.
    function _compatible(bytes memory m1, bytes memory m2) internal virtual pure returns (bool);
}
