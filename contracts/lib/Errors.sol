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
    error LicenseRegistry__EmptyLicenseUrl();
    error LicenseRegistry__ParamVerifierLengthMismatch();
    error LicenseRegistry__InvalidParamVerifierType();
    error LicenseRegistry__PolicyNotFound();
    error LicenseRegistry__NotLicensee();
}
