// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Errors Library
/// @notice Library for all Story Protocol contract errors.
library Errors {
    ////////////////////////////////////////////////////////////////////////////
    //                            Dispute Module                              //
    ////////////////////////////////////////////////////////////////////////////

    error DisputeModule__ZeroArbitrationPolicy();
    error DisputeModule__ZeroArbitrationRelayer();
    error DisputeModule__ZeroDisputeTag();
    error DisputeModule__ZeroHashToDisputeSummary();
    error DisputeModule__NotWhitelistedArbitrationPolicy();
    error DisputeModule__NotWhitelistedDisputeTag();
    error DisputeModule__NotWhitelistedArbitrationRelayer();
    error DisputeModule__NotDisputeInitiator();

    error ArbitrationPolicySP__ZeroDisputeModule();
    error ArbitrationPolicySP__ZeroPaymentToken();
    error ArbitrationPolicySP__NotDisputeModule();

    ////////////////////////////////////////////////////////////////////////////
    //                            Royalty Module                              //
    ////////////////////////////////////////////////////////////////////////////

    error RoyaltyModule__ZeroRoyaltyPolicy();
    error RoyaltyModule__NotWhitelistedRoyaltyPolicy();
    error RoyaltyModule__AlreadySetRoyaltyPolicy();

    error RoyaltyPolicyLS__ZeroRoyaltyModule();
    error RoyaltyPolicyLS__ZeroLiquidSplitFactory();
    error RoyaltyPolicyLS__ZeroLiquidSplitMain();
    error RoyaltyPolicyLS__NotRoyaltyModule();
    error RoyaltyPolicyLS__TransferFailed();
}
