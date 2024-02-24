// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IPResolver } from "../../resolvers/IPResolver.sol";

interface IRegistrationModule {
    /// @notice Emitted when a root-level IP is registered.
    /// @param caller The address of the caller.
    /// @param ipId The address of the IP that was registered.
    /// @param policyId The policy that identifies the licensing terms of the IP.
    event RootIPRegistered(address indexed caller, address indexed ipId, uint256 indexed policyId);

    /// @notice Emitted when a derivative IP is registered.
    /// @param caller The address of the caller.
    /// @param ipId The address of the IP that was registered.
    /// @param licenseIds The licenses that were used to register the derivative IP.
    event DerivativeIPRegistered(address indexed caller, address indexed ipId, uint256[] licenseIds);

    /// @notice Returns the metadata resolver used by the registration module.
    function ipResolver() external view returns (IPResolver);

    /// @notice Registers a root-level IP into the protocol. Root-level IPs can be thought of as organizational hubs
    /// for encapsulating policies that actual IPs can use to register through. As such, a root-level IP is not an
    /// actual IP, but a container for IP policy management for their child IP assets.
    /// @param policyId The policy that identifies the licensing terms of the IP.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenId The token id of the NFT bound to the root-level IP.
    /// @param ipName The name assigned to the new IP.
    /// @param contentHash The content hash of the IP being registered.
    /// @param externalURL An external URI to link to the IP.
    function registerRootIp(
        uint256 policyId,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 contentHash,
        string calldata externalURL
    ) external returns (address);

    /// @notice Registers derivative IPs into the protocol. Derivative IPs are IP assets that inherit policies from
    /// parent IPs by burning acquired license NFTs.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param tokenContract The address of the NFT bound to the derivative IP.
    /// @param tokenId The token id of the NFT bound to the derivative IP.
    /// @param ipName The name assigned to the new IP.
    /// @param contentHash The content hash of the IP being registered.
    /// @param externalURL An external URI to link to the IP.
    /// @param royaltyContext The royalty context for the derivative IP.
    function registerDerivativeIp(
        uint256[] calldata licenseIds,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 contentHash,
        string calldata externalURL,
        bytes calldata royaltyContext
    ) external;
}
