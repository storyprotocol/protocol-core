// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicy {
    /// @notice Executes royalty related logic on minting a license
    /// @param _ipId The children ipId that is being linked to parents
    /// @param _licenseData The license data custom to each the royalty policy
    /// @param _externalData The external data custom to each the royalty policy
    function onLicenseMinting(address _ipId, bytes calldata _licenseData, bytes calldata _externalData) external;

    /// @notice Executes royalty related logic on linking to parents
    /// @param _ipId The children ipId that is being linked to parents
    /// @param _parentIpIds The selected parent ipIds
    /// @param _licenseData The license data custom to each the royalty policy
    /// @param _externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address _ipId,
        address[] calldata _parentIpIds,
        bytes[] memory _licenseData,
        bytes calldata _externalData
    ) external;

    /// @notice Allows to pay a royalty
    /// @param caller The caller
    /// @param ipId The ipId
    /// @param token The token to pay
    /// @param amount The amount to pay
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external;
}
