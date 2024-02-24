// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title IP Library
/// @notice Library for constants, structs, and helper functions used for IP.
library IP {
    /// @notice Core metadata to associate with each IP.
    struct MetadataV1 {
        // The name associated with the IP.
        string name;
        // A keccak-256 hash of the IP content.
        bytes32 hash;
        // The date which the IP was registered.
        uint64 registrationDate;
        // The address of the initial IP registrant.
        address registrant;
        // An external URI associated with the IP.
        string uri;
    }
}
