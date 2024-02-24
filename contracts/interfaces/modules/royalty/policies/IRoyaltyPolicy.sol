// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicy {
    /// @notice Executes royalty related logic on minting a license
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(address ipId, bytes calldata licenseData, bytes calldata externalData) external;

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external;

    /// @notice Allows the caller to pay royalties to the given IP asset
    /// @param caller The caller is the address from which funds will transferred from
    /// @param ipId The ipId of the receiver of the royalties
    /// @param token The token to pay
    /// @param amount The amount to pay
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external;
}
