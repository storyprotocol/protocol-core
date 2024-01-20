// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

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