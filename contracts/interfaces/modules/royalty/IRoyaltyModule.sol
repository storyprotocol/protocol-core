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

    /// @notice Indicates if a royalty policy is whitelisted
    /// @param royaltyPolicy The address of the royalty policy
    function isWhitelistedRoyaltyPolicy(address royaltyPolicy) external view returns (bool);

    /// @notice Indicates if a royalty token is whitelisted
    /// @param token The address of the royalty token
    function isWhitelistedRoyaltyToken(address token) external view returns (bool);

    /// @notice Indicates the royalty policy for a given ipId
    /// @param ipId The ipId
    function royaltyPolicies(address ipId) external view returns (address);

    /// @notice Indicates if a royalty policy is immutable
    /// @param ipId The ipId
    function isRoyaltyPolicyImmutable(address ipId) external view returns (bool);

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

    /// @notice Executes royalty related logic on license minting
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param royaltyPolicy The royalty policy address of the license being minted
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(address ipId, address royaltyPolicy, bytes calldata licenseData, bytes calldata externalData) external;
    
    /// @notice Executes royalty related logic on linking to parents
    /// @param ipId The children ipId that is being linked to parents
    /// @param royaltyPolicy The common royalty policy address of all the licenses being burned
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(address ipId, address royaltyPolicy, address[] calldata parentIpIds, bytes[] memory licenseData, bytes calldata externalData) external;

    /// @notice Allows a sender to to pay royalties on behalf of an ipId
    /// @param receiverIpId The ipId that receives the royalties
    /// @param payerIpId The ipId that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payRoyaltyOnBehalf(address receiverIpId, address payerIpId, address token, uint256 amount) external;
}
