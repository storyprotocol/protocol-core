// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Errors Library
/// @notice Library for all Story Protocol contract errors.
library Errors {    
    ////////////////////////////////////////////////////////////////////////////
    //                            LicenseRegistry                             //
    ////////////////////////////////////////////////////////////////////////////
    
    /// @notice Error thrown when a policy is already set for an IP ID.
    error LicenseRegistry__PolicyAlreadySetForIpId();
    error LicenseRegistry__FrameworkNotFound();
    error LicenseRegistry__EmptyLicenseUrl();
    error LicenseRegistry__ParamVerifierLengthMismatch();
    error LicenseRegistry__InvalidParamVerifierType();
    error LicenseRegistry__PolicyNotFound();
    error LicenseRegistry__NotLicensee();
    error LicenseRegistry__ParentIdEqualThanChild();
    error LicenseRegistry__LicensorDoesntHaveThisPolicy();

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

    ////////////////////////////////////////////////////////////////////////////
    //                             ModuleRegistry                             //
    ////////////////////////////////////////////////////////////////////////////

    error ModuleRegistry__ModuleAddressZeroAddress();
    error ModuleRegistry__ModuleAddressNotContract();
    error ModuleRegistry__ModuleAlreadyRegistered();
    error ModuleRegistry__NameEmptyString();
    error ModuleRegistry__NameAlreadyRegistered();
    error ModuleRegistry__NameDoesNotMatch();
    error ModuleRegistry__ModuleNotRegistered();

    ////////////////////////////////////////////////////////////////////////////
    //                             AccessController                           //
    ////////////////////////////////////////////////////////////////////////////

    error AccessController__IPAccountIsZeroAddress();
    error AccessController__IPAccountIsNotValid();
    error AccessController__SignerIsZeroAddress();
    error AccessController__CallerIsNotIPAccount();
    error AccessController__PermissionIsNotValid();
}
