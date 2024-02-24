// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IP } from "../../lib/IP.sol";
import { MetadataProviderBase } from "./MetadataProviderBase.sol";
import { Errors } from "../../lib/Errors.sol";

/// @title IP Metadata Provider v1
/// @notice Storage provider for Story Protocol canonical IP metadata (v1).
contract MetadataProviderV1 is MetadataProviderBase {
    /// @notice Initializes the metadata provider contract.
    /// @param ipAssetRegistry The protocol-wide IP asset registry.
    constructor(address ipAssetRegistry) MetadataProviderBase(ipAssetRegistry) {}

    /// @notice Fetches the metadata linked to an IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return metadata The metadata linked to the IP asset.
    function metadata(address ipId) external view returns (IP.MetadataV1 memory) {
        return _metadataV1(ipId);
    }

    /// @notice Gets the name associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return name The name associated with the IP asset.
    function name(address ipId) external view returns (string memory) {
        return _metadataV1(ipId).name;
    }

    /// @notice Gets the hash associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return hash The hash associated with the IP asset.
    function hash(address ipId) external view returns (bytes32) {
        return _metadataV1(ipId).hash;
    }

    /// @notice Gets the date in which the IP asset was registered.
    /// @param ipId The address identifier of the IP asset.
    /// @return registrationDate The date in which the IP asset was registered.
    function registrationDate(address ipId) external view returns (uint64) {
        return _metadataV1(ipId).registrationDate;
    }

    /// @notice Gets the initial registrant address of the IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return registrant The initial registrant address of the IP asset.
    function registrant(address ipId) external view returns (address) {
        return _metadataV1(ipId).registrant;
    }

    /// @notice Gets the external URI associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return uri The external URI associated with the IP asset.
    function uri(address ipId) external view returns (string memory) {
        return _metadataV1(ipId).uri;
    }

    /// @dev Checks that the data conforms to the canonical metadata standards.
    /// @param data The canonical metadata in bytes to verify.
    function _verifyMetadata(bytes memory data) internal virtual override {
        IP.MetadataV1 memory decodedMetadata = abi.decode(data, (IP.MetadataV1));
        if (decodedMetadata.registrant == address(0)) {
            revert Errors.MetadataProvider__RegistrantInvalid();
        }
    }

    /// @dev Checks whether two sets of metadata are compatible with one another.
    /// TODO: Add try-catch for ABI-decoding error handling.
    function _compatible(bytes memory m1, bytes memory m2) internal pure virtual override returns (bool) {
        IP.MetadataV1 memory m1Decoded = abi.decode(m1, (IP.MetadataV1));
        IP.MetadataV1 memory m2Decoded = abi.decode(m2, (IP.MetadataV1));
        return _hash(m1Decoded) == _hash(m2Decoded);
    }

    /// @dev Gets the bytes32 hash for a MetadataV1 data struct.
    function _hash(IP.MetadataV1 memory data) internal pure returns (bytes32) {
        return keccak256(abi.encode(data.name, data.hash, data.registrationDate, data.registrant, data.uri));
    }

    /// @dev Get the decoded canonical metadata belonging to an IP asset.
    function _metadataV1(address ipId) internal view returns (IP.MetadataV1 memory) {
        return abi.decode(_ipMetadata[ipId], (IP.MetadataV1));
    }
}
