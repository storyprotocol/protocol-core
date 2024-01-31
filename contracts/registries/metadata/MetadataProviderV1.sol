// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IP } from "contracts/lib/IP.sol";
import { MetadataProviderBase } from "./MetadataProviderBase.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IP Metadata Provider v1
/// @notice Storage provider for Story Protocol canonical IP metadata (v1).
contract MetadataProviderV1 is MetadataProviderBase {

    /// @notice Initializes the metadata provider contract.
    /// @param ipAssetRegistry The protocol-wide IP asset registry.
    constructor(address ipAssetRegistry) MetadataProviderBase(ipAssetRegistry) {}

    /// @notice Sets the IP metadata associated with an IP asset based on its IP ID.
    /// @param ipId The IP id of the IP asset to set metadata for.
    /// @param data The metadata in bytes to set for the IP asset.
    function setMetadata(address ipId, bytes calldata data) external override onlyIPAssetRegistry {
        IP.MetadataV1 memory decodedMetadata = abi.decode(data, (IP.MetadataV1));
        if (bytes(decodedMetadata.name).length == 0) {
            revert Errors.MetadataProvider__NameInvalid();
        }
        if (decodedMetadata.hash == "") {
            revert Errors.MetadataProvider__HashInvalid();
        }
        if (decodedMetadata.registrationDate != uint64(block.timestamp)) {
            revert Errors.MetadataProvider__RegistrationDateInvalid();
        }
        if (decodedMetadata.registrant == address(0)) {
            revert Errors.MetadataProvider__RegistrantInvalid();
        }
        if (bytes(decodedMetadata.uri).length == 0) {
            revert Errors.MetadataProvider__RegistrantInvalid();
        }
        _ipMetadata[ipId] = data;
        emit MetadataSet(ipId, data);
    }

    /// @dev Checks whether two sets of metadata are compatible with one another.
    function _compatible(bytes memory m1, bytes memory m2) internal virtual override pure returns (bool) {
        IP.MetadataV1 memory m1Decoded = abi.decode(m1, (IP.MetadataV1));
        IP.MetadataV1 memory m2Decoded = abi.decode(m2, (IP.MetadataV1));
        return _hash(m1Decoded) == _hash(m2Decoded);
    }

    /// @dev Gets the bytes32 hash for a MetadataV1 data struct.
    function _hash(IP.MetadataV1 memory data) internal pure returns(bytes32) {
        return keccak256(
            abi.encodePacked(
                data.name,
                data.hash,
                data.registrationDate,
                data.registrant,
                data.uri
            )
        );
    }
}
