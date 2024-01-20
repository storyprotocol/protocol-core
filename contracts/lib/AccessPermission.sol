// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

/// @title Access Permission Library
/// @notice Library for IPAccount access control permissions.
///         These permissions are used by the AccessController.
library AccessPermission {
    // ABSTAIN means having not enough information to make decision at current level,
    // deferred decision to up level permission.
    uint8 public constant ABSTAIN = 0;

    // ALLOW means the permission is granted to transaction signer to call the function.
    uint8 public constant ALLOW = 1;

    // DENY means the permission is denied to transaction signer to call the function.
    uint8 public constant DENY = 2;
}
