// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicy {   
    /// @notice Initializes the royalty policy
    /// @param ipId The ipId
    /// @param parentsIpIds The parent ipIds
    /// @param data The data to initialize the policy
    function initPolicy(address ipId, address[] calldata parentsIpIds, bytes calldata data) external;

    /// @notice Allows to pay a royalty
    /// @param caller The caller
    /// @param ipId The ipId
    /// @param token The token to pay
    /// @param amount The amount to pay
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external;
}