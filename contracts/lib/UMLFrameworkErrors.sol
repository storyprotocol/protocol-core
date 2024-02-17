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
    error UMLPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers();
    error UMLPolicyFrameworkManager__CommecialDisabled_CantAddRevShare();
    error UMLPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution();
    error UMLPolicyFrameworkManager__DerivativesDisabled_CantAddApproval();
    error UMLPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal();
    error UMLPolicyFrameworkManager__RightsNotFound();
    error UMLPolicyFrameworkManager__CommercialDisabled_CantAddRoyaltyPolicy();
    error UMLPolicyFrameworkManager__CommecialEnabled_RoyaltyPolicyRequired();
    error UMLPolicyFrameworkManager__ReciprocalButDifferentPolicyIds();
    error UMLPolicyFrameworkManager__ReciprocalValueMismatch();
    error UMLPolicyFrameworkManager__CommercialValueMismatch();
    error UMLPolicyFrameworkManager__DerivativesValueMismatch();
    error UMLPolicyFrameworkManager__StringArrayMismatch();
    error UMLPolicyFrameworkManager__CommecialDisabled_CantAddMintingFee();
    error UMLPolicyFrameworkManager__CommecialDisabled_CantAddMintingFeeToken();
}
