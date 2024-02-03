// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title UMLFrameworkErrors Errors Library
/// @notice Library for all UMLFramework related contract errors.
library UMLFrameworkErrors {
    ////////////////////////////////////////////////////////////////////////////
    //                         UMLPolicyFrameworkManager                      //
    ////////////////////////////////////////////////////////////////////////////

    error UMLPolicyFrameworkManager__CommecialDisabled_CantAddAttribution();
    error UMLPolicyFrameworkManager__CommecialDisabled_CantAddCommercializers();
    error UMLPolicyFrameworkManager__CommecialDisabled_CantAddRevShare();
    error UMLPolicyFrameworkManager__CommecialDisabled_CantAddDerivRevShare();
    error UMLPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution();
    error UMLPolicyFrameworkManager__DerivativesDisabled_CantAddApproval();
    error UMLPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal();
    error UMLPolicyFrameworkManager__DerivativesDisabled_CantAddRevShare();
    error UMLPolicyFrameworkManager__RightsNotFound();
    
    error UMLPolicyFrameworkManager__ReciprocalPolicyMismatch();
    error UMLPolicyFrameworkManager__ReciprocalValueMismatch();
}
