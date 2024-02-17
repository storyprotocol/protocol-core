// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title PILFrameworkErrors Errors Library
/// @notice Library for all PILFramework related contract errors.
library PILFrameworkErrors {
    ////////////////////////////////////////////////////////////////////////////
    //                         PILPolicyFrameworkManager                      //
    ////////////////////////////////////////////////////////////////////////////

    error PILPolicyFrameworkManager__CommecialDisabled_CantAddAttribution();
    error PILPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers();
    error PILPolicyFrameworkManager__CommecialDisabled_CantAddRevShare();
    error PILPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution();
    error PILPolicyFrameworkManager__DerivativesDisabled_CantAddApproval();
    error PILPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal();
    error PILPolicyFrameworkManager__RightsNotFound();
    error PILPolicyFrameworkManager__CommercialDisabled_CantAddRoyaltyPolicy();
    error PILPolicyFrameworkManager__CommecialEnabled_RoyaltyPolicyRequired();
    error PILPolicyFrameworkManager__ReciprocalButDifferentPolicyIds();
    error PILPolicyFrameworkManager__ReciprocalValueMismatch();
    error PILPolicyFrameworkManager__CommercialValueMismatch();
    error PILPolicyFrameworkManager__StringArrayMismatch();
    error PILPolicyFrameworkManager__CommecialDisabled_CantAddMintingFee();
    error PILPolicyFrameworkManager__CommecialDisabled_CantAddMintingFeeToken();
}
