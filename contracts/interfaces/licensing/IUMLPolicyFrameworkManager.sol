// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/licensing/IPolicyFrameworkManager.sol";

/// @notice Licensing parameters for the UML standard
/// @param attribution Whether or not attribution is required when reproducing the work
/// @param transferable Whether or not the license is transferable
/// @param commercialUse Whether or not the work can be used commercially
/// @param commercialAttribution Whether or not attribution is required when reproducing the work commercially
/// @param commercializers List of commericializers that are allowed to commercially exploit the work. If empty
/// then no restrictions.
/// @param commercialRevShare Percentage of revenue that must be shared with the licensor
/// @param derivativesAllowed Whether or not the licensee can create derivatives of his work
/// @param derivativesAttribution Whether or not attribution is required for derivatives of the work
/// @param derivativesApproval Whether or not the licensor must approve derivatives of the work before they can be
/// linked to the licensor IP ID
/// @param derivativesReciprocal Whether or not the licensee must license derivatives of the work under the same terms.
/// @param derivativesRevShare Percentage of revenue that must be shared with the licensor for derivatives of the work
/// @param territories List of territories where the license is valid. If empty, global.
/// @param distributionChannels List of distribution channels where the license is valid. Empty if no restrictions.
/// @param royaltyPolicy Address of a royalty policy contract (e.g. RoyaltyPolicyLS) that will handle royalty payments
struct UMLPolicy {
    bool attribution;
    bool transferable;
    bool commercialUse;
    bool commercialAttribution;
    string[] commercializers;
    uint32 commercialRevShare;
    bool derivativesAllowed;
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    uint32 derivativesRevShare;
    string[] territories;
    string[] distributionChannels;
    address royaltyPolicy;
}

struct UMLRights {
    bool commercial;
    bool derivable;
    bool reciprocalSet;
}

struct UMLRights {
    bool commercial;
    bool derivable;
    bool reciprocalSet;
}


/// @title IUMLPolicyFrameworkManager
/// @notice Defines the interface for a Policy Framework Manager compliant with the UML standard
interface IUMLPolicyFrameworkManager is IPolicyFrameworkManager {
    /// @notice Registers a new policy to the registry
    /// @dev Must encode the policy into bytes to be stored in the LicenseRegistry
    /// @param umlPolicy UMLPolicy compliant licensing term values
    function registerPolicy(UMLPolicy calldata umlPolicy) external returns (uint256 policyId);
    /// @notice Fetchs a policy from the registry, decoding the raw bytes into a UMLPolicy struct
    /// @param policyId  The ID of the policy to fetch
    /// @return policy The UMLPolicy struct
    function getPolicy(uint256 policyId) external view returns (UMLPolicy memory policy);
    
    function getRights(address ipId) external view returns (UMLRights memory rights);
}