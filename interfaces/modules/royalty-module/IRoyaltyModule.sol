// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title RoyaltyModule interface
interface IRoyaltyModule {
    /// @notice Whitelist a royalty policy
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external;

    /// @notice Sets the royalty policy for an ipId
    /// @param ipId The ipId
    /// @param royaltyPolicy The address of the royalty policy
    /// @param data The data to initialize the policy
    function setRoyaltyPolicy(address ipId, address royaltyPolicy, bytes calldata data) external;

    /// @notice Allows an IPAccount to pay royalties
    /// @param ipId The ipId
    /// @param token The token to pay the royalties in
    /// @param amount The amount to pay
    function payRoyalty(address ipId, address token, uint256 amount) external;

    /// @notice Gets the royalty policy for a given ipId
    function royaltyPolicies(address ipId) external view returns (address royaltyPolicy);
}