// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title PILFrameworkErrors Errors Library
/// @notice Library for all PILFramework related contract errors.
library PILFrameworkErrors {
    ////////////////////////////////////////////////////////////////////////////
    //                         PILPolicyFrameworkManager                      //
    ////////////////////////////////////////////////////////////////////////////

    error PILPolicyFrameworkManager__CommercialDisabled_CantAddAttribution();
    error PILPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers();
    error PILPolicyFrameworkManager__CommercialDisabled_CantAddRevShare();
    error PILPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution();
    error PILPolicyFrameworkManager__DerivativesDisabled_CantAddApproval();
    error PILPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal();
    error PILPolicyFrameworkManager__RightsNotFound();
    error PILPolicyFrameworkManager__CommercialDisabled_CantAddRoyaltyPolicy();
    error PILPolicyFrameworkManager__CommercialEnabled_RoyaltyPolicyRequired();
    error PILPolicyFrameworkManager__ReciprocalButDifferentPolicyIds();
    error PILPolicyFrameworkManager__ReciprocalValueMismatch();
    error PILPolicyFrameworkManager__CommercialValueMismatch();
    error PILPolicyFrameworkManager__StringArrayMismatch();
    error PILPolicyFrameworkManager__CommercialDisabled_CantAddMintingFee();
    error PILPolicyFrameworkManager__CommercialDisabled_CantAddMintingFeeToken();
}
