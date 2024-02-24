// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IPolicyFrameworkManager } from "../../../interfaces/modules/licensing/IPolicyFrameworkManager.sol";

/// @notice Licensing parameters for the Programmable IP License v1 (PIL) standard
/// @param transferable Whether or not the license is transferable
/// @param attribution Whether or not attribution is required when reproducing the work
/// @param commercialUse Whether or not the work can be used commercially
/// @param commercialAttribution Whether or not attribution is required when reproducing the work commercially
/// @param commercializerChecker commercializers that are allowed to commercially exploit the work. If zero address,
/// then no restrictions is enforced.
/// @param commercialRevShare Percentage of revenue that must be shared with the licensor
/// @param derivativesAllowed Whether or not the licensee can create derivatives of his work
/// @param derivativesAttribution Whether or not attribution is required for derivatives of the work
/// @param derivativesApproval Whether or not the licensor must approve derivatives of the work before they can be
/// linked to the licensor IP ID
/// @param derivativesReciprocal Whether or not the licensee must license derivatives of the work under the same terms.
/// @param territories List of territories where the license is valid. If empty, global.
/// @param distributionChannels List of distribution channels where the license is valid. Empty if no restrictions.
/// @param contentRestrictions List of content restrictions. Empty if no restrictions.
/// TODO: DO NOT deploy on production networks without hashing string[] instead of storing them
struct PILPolicy {
    bool attribution;
    bool commercialUse;
    bool commercialAttribution;
    address commercializerChecker;
    bytes commercializerCheckerData;
    uint32 commercialRevShare;
    bool derivativesAllowed;
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    string[] territories;
    string[] distributionChannels;
    string[] contentRestrictions;
}

/// @param transferable Whether or not the license is transferable
/// @param royaltyPolicy Address of a royalty policy contract (e.g. RoyaltyPolicyLS) that will handle royalty payments
/// @param mintingFee Fee to be paid when minting a license
/// @param mintingFeeToken Token to be used to pay the minting fee
/// @param policy PILPolicy compliant licensing term values
struct RegisterPILPolicyParams {
    bool transferable;
    address royaltyPolicy;
    uint256 mintingFee;
    address mintingFeeToken;
    PILPolicy policy;
}

/// @notice Struct that accumulates values of inherited policies so we can verify compatibility when inheriting
/// new policies.
/// @dev The assumption is that new policies may be added later, not only when linking an IP to its parent.
/// @param commercial Whether or not there is a policy that allows commercial use
/// @param derivativesReciprocal Whether or not there is a policy that requires derivatives to be licensed under the
/// same terms
/// @param lastPolicyId The last policy ID that was added to the IP
/// @param territoriesAcc The last hash of the territories array
/// @param distributionChannelsAcc The last hash of the distributionChannels array
/// @param contentRestrictionsAcc The last hash of the contentRestrictions array
struct PILAggregator {
    bool commercial;
    bool derivativesReciprocal;
    uint256 lastPolicyId;
    bytes32 territoriesAcc;
    bytes32 distributionChannelsAcc;
    bytes32 contentRestrictionsAcc;
}

/// @title IPILPolicyFrameworkManager
/// @notice Defines the interface for a Policy Framework Manager compliant with the PIL standard
interface IPILPolicyFrameworkManager is IPolicyFrameworkManager {
    /// @notice Registers a new policy to the registry
    /// @dev Internally, this function must generate a Licensing.Policy struct and call registerPolicy.
    /// @param params parameters needed to register a PILPolicy
    /// @return policyId The ID of the newly registered policy
    function registerPolicy(RegisterPILPolicyParams calldata params) external returns (uint256 policyId);

    /// @notice Returns the aggregation data for inherited policies of an IP asset.
    /// @param ipId The ID of the IP asset to get the aggregator for
    /// @return rights The PILAggregator struct
    function getAggregator(address ipId) external view returns (PILAggregator memory rights);

    /// @notice gets the PILPolicy for a given policy ID decoded from Licensing.Policy.frameworkData
    /// @dev Do not call this function from a smart contract, it is only for off-chain
    /// @param policyId The ID of the policy to get
    /// @return policy The PILPolicy struct
    function getPILPolicy(uint256 policyId) external view returns (PILPolicy memory policy);
}
