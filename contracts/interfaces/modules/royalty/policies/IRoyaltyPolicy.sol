// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicy {
    function onLicenseMinting(address _ipId, address[] calldata _parentIpIds, bytes calldata _data) external;

    function onLinkToParents(address _ipId, address[] calldata _parentIpIds, bytes calldata _data) external;

    /// @notice Allows to pay a royalty
    /// @param caller The caller
    /// @param ipId The ipId
    /// @param token The token to pay
    /// @param amount The amount to pay
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external;


}
