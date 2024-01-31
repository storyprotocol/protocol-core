// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IP } from "contracts/lib/IP.sol";
import { MetadataProviderV1 } from "contracts/registries/metadata/MetadataProviderV1.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Mock IP Metadata Provider v2
/// @notice Mock storage provider for upgraded Story Protocol canonical IP metadata (v2).
contract MockMetadataProviderV2 is MetadataProviderV1 {

    /// @notice Core v2 metadata to associate with each IP.
    struct MetadataV2 {
        // The name associated with the IP.
        string name;
        // A keccak-256 hash of the IP content.
        bytes32 hash;
        // The date which the IP was registered.
        uint64 registrationDate;
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
    function _verifyMetadata(bytes memory data) internal virtual override {
        super._verifyMetadata(data);
        MetadataV2 memory decodedMetadata = abi.decode(data, (MetadataV2));
        if (bytes(decodedMetadata.nickname).length == 0) {
            revert Errors.MetadataProvider__NameInvalid();
        }
        if (decodedMetadata.decimals == 0) {
            revert Errors.MetadataProvider__HashInvalid();
        }
    }

    /// @dev Checks whether two sets of metadata are compatible with one another.
    function _compatible(bytes memory m1, bytes memory m2) internal virtual override pure returns (bool) {
        MetadataV2 memory m1Decoded = abi.decode(m1, (MetadataV2));
        MetadataV2 memory m2Decoded = abi.decode(m2, (MetadataV2));
        return _hash(m1Decoded) == _hash(m2Decoded);
    }

    /// @dev Gets the bytes32 hash for a MetadataV1 data struct.
    function _hash(MetadataV2 memory data) internal pure returns(bytes32) {
        return keccak256(
            abi.encodePacked(
                data.name,
                data.hash,
                data.registrationDate,
                data.registrant,
                data.uri,
                data.nickname,
                data.decimals
            )
        );
    }
}
