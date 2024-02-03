// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title UMLFrameworkErrors Errors Library
/// @notice Library for all UMLFramework related contract errors.
library UMLFrameworkErrors {
    ////////////////////////////////////////////////////////////////////////////
    //                         UMLPolicyFrameworkManager                      //
    ////////////////////////////////////////////////////////////////////////////

    error UMLPolicyFrameworkManager_CommecialDisabled_CantAddAttribution();
    error UMLPolicyFrameworkManager_CommecialDisabled_CantAddCommercializers();
    error UMLPolicyFrameworkManager_CommecialDisabled_CantAddRevShare();
    error UMLPolicyFrameworkManager_CommecialDisabled_CantAddDerivRevShare();
    error UMLPolicyFrameworkManager_CommecialDisabled_CantAddRoyaltyPolicy();
    error UMLPolicyFrameworkManager_CommecialEnabled_RoyaltyPolicyRequired();
    error UMLPolicyFrameworkManager_DerivativesDisabled_CantAddAttribution();
    error UMLPolicyFrameworkManager_DerivativesDisabled_CantAddApproval();
    error UMLPolicyFrameworkManager_DerivativesDisabled_CantAddReciprocal();
    error UMLPolicyFrameworkManager_DerivativesDisabled_CantAddRevShare();
    error UMLPolicyFrameworkManager_RightsNotFound();

    error UMLPolicyFrameworkManager_NewCommercialPolicyNotAccepted();
    error UMLPolicyFrameworkManager_NewDerivativesPolicyNotAccepted();
    error UMLPolicyFrameworkManager_ReciprocaConfiglNegatesNewPolicy();
}
