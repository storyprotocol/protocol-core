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
    /// @param ipId The ID of IP asset
    /// @param royaltyPolicy The address of the royalty policy
    /// @param data The data to initialize the policy
    event RoyaltyPolicySet(address ipId, address royaltyPolicy, bytes data);

    /// @notice Event emitted when royalties are paid
    /// @param receiverIpId The ID of IP asset that receives the royalties
    /// @param payerIpId The ID of IP asset that pays the royalties
    /// @param sender The address that pays the royalties on behalf of the payer ID of IP asset
    /// @param token The token that is used to pay the royalties
    /// @param amount The amount that is paid
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);

    /// @notice Returns the licensing module address
    function LICENSING_MODULE() external view returns (address);

    /// @notice Indicates if a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    /// @return isWhitelisted True if the royalty policy is whitelisted
    function isWhitelistedRoyaltyPolicy(address royaltyPolicy) external view returns (bool);

    /// @notice Indicates if a royalty token is whitelisted
    /// @param token The address of the royalty token
    /// @return isWhitelisted True if the royalty token is whitelisted
    function isWhitelistedRoyaltyToken(address token) external view returns (bool);

    /// @notice Indicates the royalty policy for a given IP asset
    /// @param ipId The ID of IP asset
    /// @return royaltyPolicy The address of the royalty policy
    function royaltyPolicies(address ipId) external view returns (address);

    /// @notice Indicates if a royalty policy is immutable
    /// @param ipId The ID of IP asset
    /// @return isImmutable True if the royalty policy is immutable
    function isRoyaltyPolicyImmutable(address ipId) external view returns (bool);

    /// @notice Sets the licensing module
    /// @dev Enforced to be only callable by the protocol admin
    /// @param licensingModule The address of the licensing module
    function setLicensingModule(address licensingModule) external;

    /// @notice Whitelist a royalty policy
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external;

    /// @notice Whitelist a royalty token
    /// @dev Enforced to be only callable by the protocol admin
    /// @param token The token address
    /// @param allowed Indicates if the token is whitelisted or not
    function whitelistRoyaltyToken(address token, bool allowed) external;

    /// @notice Sets the royalty policy for a given IP asset
    /// @dev Enforced to be only callable by the licensing module
    /// @param ipId The ID of IP asset
    /// @param royaltyPolicy The address of the royalty policy
    /// @param parentIpIds List of parent IP asset IDs
    /// @param data The data to initialize the policy
    function setRoyaltyPolicy(
        address ipId,
        address royaltyPolicy,
        address[] calldata parentIpIds,
        bytes calldata data
    ) external;

    /// @notice Sets the royalty policy as immutable
    /// @dev Enforced to be only callable by the licensing module
    /// @param ipId The ID of IP asset
    function setRoyaltyPolicyImmutable(address ipId) external;

    // TODO: deprecate in favor of more flexible royalty data getters
    /// @notice Returns the minRoyalty for a given IP asset
    /// @param ipId The ID of IP asset
    /// @return minRoyalty The minimum royalty percentage, 10 units = 1%
    function minRoyaltyFromDescendants(address ipId) external view returns (uint256);

    /// @notice Allows a sender to to pay royalties on behalf of an given IP asset
    /// @param receiverIpId The ID of IP asset that receives the royalties
    /// @param payerIpId The ID of IP asset that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external;
}
