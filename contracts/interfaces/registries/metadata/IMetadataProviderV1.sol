// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IP } from "../../../lib/IP.sol";
import { IMetadataProvider } from "./IMetadataProvider.sol";

/// @title Metadata Provider v1 Interface
interface IMetadataProviderV1 is IMetadataProvider {
    /// @notice Fetches the metadata linked to an IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return metadata The metadata linked to the IP asset.
    function metadata(address ipId) external view returns (IP.MetadataV1 memory);

    /// @notice Gets the name associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return name The name associated with the IP asset.
    function name(address ipId) external view returns (string memory);

    /// @notice Gets the hash associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return hash The hash associated with the IP asset.
    function hash(address ipId) external view returns (bytes32);

    /// @notice Gets the date in which the IP asset was registered.
    /// @param ipId The address identifier of the IP asset.
    /// @return registrationDate The date in which the IP asset was registered.
    function registrationDate(address ipId) external view returns (uint64);

    /// @notice Gets the initial registrant address of the IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return registrant The initial registrant address of the IP asset.
    function registrant(address ipId) external view returns (address);

    /// @notice Gets the external URI associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    /// @return uri The external URI associated with the IP asset.
    function uri(address ipId) external view returns (string memory);
}
