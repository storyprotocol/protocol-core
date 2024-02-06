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

    /// @notice This struct is used to represent permissions in batch operations within the AccessController.
    /// @param ipAccount The IPAccount address for which the permission is being set.
    /// @param signer The address of the signer of the transaction.
    /// @param to The address of the recipient of the transaction.
    /// @param func The function selector for the transaction.
    /// @param permission The permission level for the transaction (0 = ABSTAIN, 1 = ALLOW, 2 = DENY).
    struct Permission {
        address ipAccount;
        address signer;
        address to;
        bytes4 func;
        uint8 permission;
    }
}
