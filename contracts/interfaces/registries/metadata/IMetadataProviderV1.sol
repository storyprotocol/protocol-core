// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IMetadataProvider } from "contracts/interfaces/registries/metadata/IMetadataProvider.sol";

/// @title Metadata Provider v1 Interface
interface IMetadataProviderV1 is IMetadataProvider {
    /// @notice Gets the name associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    function name(address ipId) external view returns (string memory);

    /// @notice Gets the hash associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    function hash(address ipId) external view returns (bytes32);

    /// @notice Gets the date in which the IP asset was registered.
    /// @param ipId The address identifier of the IP asset.
    function registrationDate(address ipId) external view returns (uint64);

    /// @notice Gets the initial registrant address of the IP asset.
    /// @param ipId The address identifier of the IP asset.
    function registrant(address ipId) external view returns (address);

    /// @notice Gets the external URI associated with the IP asset.
    /// @param ipId The address identifier of the IP asset.
    function uri(address ipId) external view returns (string memory);
}
