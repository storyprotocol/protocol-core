// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { MetadataProviderV1 } from "contracts/registries/metadata/MetadataProviderV1.sol";

/// @title Mock IP Metadata Provider v2
/// @notice Mock storage provider for upgraded Story Protocol canonical IP metadata (v2).
contract MockMetadataProviderV2 is MetadataProviderV1 {
    /// @notice Core v2 metadata to associate with each IP.
    struct MetadataV2 {
        // The name associated with the IP.
        string name;
        // A keccak-256 hash of the IP content.
        bytes32 hash;
        ////////////////////////////////////////////////////////////////////////
        //             Note:  Missing registration memory encoding           ///
        ////////////////////////////////////////////////////////////////////////
        // The date which the IP was registered.
        // uint64 registrationDate;

        // The address of the initial IP registrant.
        address registrant;
        // An external URI associated with the IP.
        string uri;
        // A nickname to associate with the metadata.
        string nickname;
        // Random decimals to incorporate into the metadata.
        uint256 decimals;
    }

    /// @notice Initializes the metadata provider contract.
    /// @param ipAssetRegistry The protocol-wide IP asset registry.
    constructor(address ipAssetRegistry) MetadataProviderV1(ipAssetRegistry) {}

    /// @dev Checks that the data conforms to the canonical metadata standards.
    /// @param data The canonical metadata in bytes to verify.
    function _verifyMetadata(bytes memory data) internal virtual override {}

    /// @dev Checks whether two sets of metadata are compatible with one another.
    function _compatible(bytes memory, bytes memory) internal pure virtual override returns (bool) {
        return true;
    }
}
