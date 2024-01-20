// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { IP } from "contracts/lib/IP.sol";

/// @notice Resolver Interface
interface IIPMetadataResolver is IResolver {

    /// @notice Fetches core metadata attributed to a specific IP.
    function metadata(address ipId) external view returns (IP.Metadata memory);

    /// @notice Fetches the canonical name associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    function name(address ipId) external view returns (string memory);

    /// @notice Fetches the description associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @return The string descriptor of the IP.
    function description(address ipId) external view returns (string memory);

    /// @notice Fetches the keccak-256 hash associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @return The bytes32 content hash of the IP.
    function hash(address ipId) external view returns (bytes32);

    /// @notice Fetches the date of registration of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function registrationDate(address ipId) external view returns (uint64);

    /// @notice Fetches the initial registrant of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function registrant(address ipId) external view returns (address);

    /// @notice Fetches the current owner of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function owner(address ipId) external view returns (address);

    /// @notice Fetches an IP owner defined URI associated with the IP.
    /// @param ipId The canonical ID of the specified IP.
    function uri(address ipId) external view returns (string memory);

    /// @notice Sets the core metadata associated with an IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param data Metadata to be stored for the IP in the metadata resolver.
    function setMetadata(address ipId, IP.MetadataRecord calldata data) external;

    /// @notice Sets the name associated with an IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param name The string name to associate with the IP.
    function setName(address ipId, string calldata name) external;

    /// @notice Sets the description associated with an IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param description The string description to associate with the IP.
    function setDescription(address ipId, string calldata description) external;

    /// @notice Sets the keccak-256 hash associated with an IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param hash The keccak-256 hash to associate with the IP.
    function setHash(address ipId, bytes32 hash) external;

    /// @notice Sets an IP owner defined URI to associate with the IP.
    /// @param ipId The canonical ID of the specified IP.
    function setURI(address ipId, string calldata uri) external;

}
