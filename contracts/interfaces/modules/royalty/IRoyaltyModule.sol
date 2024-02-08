// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IModule } from "../../modules/base/IModule.sol";

/// @title RoyaltyModule interface
interface IRoyaltyModule is IModule {
    /// @notice Event emitted when a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    event RoyaltyPolicyWhitelistUpdated(address royaltyPolicy, bool allowed);

    /// @notice Event emitted when a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @param allowed Indicates if the royalty token is whitelisted or not
    event RoyaltyTokenWhitelistUpdated(address token, bool allowed);

    /// @notice Event emitted when a royalty policy is set
    /// @param ipId The ipId
    /// @param royaltyPolicy The address of the royalty policy
    /// @param data The data to initialize the policy
    event RoyaltyPolicySet(address ipId, address royaltyPolicy, bytes data);

    /// @notice Event emitted when royalties are paid
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerIpId The ipId that pays the royalties
    /// @param sender The address that pays the royalties on behalf of the payer ipId
    /// @param token The token that is used to pay the royalties
    /// @param amount The amount that is paid
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);

    /// @notice Event emitted when the license minting fee is paid
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token that is used to pay the royalties
    /// @param amount The amount paid
    event LicenseMintingFeePaid(address receiverIpId, address payerAddress, address token, uint256 amount);

    /// @notice Sets the licensing module
    /// @param licensingModule The address of the licensing module
    function setLicensingModule(address licensingModule) external;

    /// @notice Whitelist a royalty policy
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external;

    /// @notice Whitelist a royalty token
    /// @param token The token address
    /// @param allowed Indicates if the token is whitelisted or not
    function whitelistRoyaltyToken(address token, bool allowed) external;

    /// @notice Sets the royalty policy for an ipId
    /// @param ipId The ipId
    /// @param royaltyPolicy The address of the royalty policy
    /// @param parentIpIds The parent ipIds
    /// @param data The data to initialize the policy
    function setRoyaltyPolicy(
        address ipId,
        address royaltyPolicy,
        address[] calldata parentIpIds,
        bytes calldata data
    ) external;

    /// @notice Allows a sender to to pay royalties on behalf of an ipId
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerIpId The ipId that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external;

    /// @notice Allows the sender to pay the license minting fee
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerAddress The address that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payLicenseMintingFee(address receiverIpId, address payerAddress, address token, uint256 amount) external;
}
