// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

/// @title IP Library
/// @notice Library for constants, structs, and helper functions used for IP.
library IP {
    /// @notice Core metadata associated with an IP.
    struct Metadata {
        // The current owner of the IP.
        address owner;
        // The name associated with the IP.
        string name;
        // A description associated with the IP.
        string description;
        // A keccak-256 hash of the IP content.
        bytes32 hash;
        // The date which the IP was registered.
        uint64 registrationDate;
        // The address of the initial IP registrant.
        address registrant;
        // The token URI associated with the IP.
        string uri;
    }

    /// @notice Core metadata exclusively saved by the IP resolver.
    /// @dev Resolved attributes not referenced here are processed through
    ///      their corresponding data modules (e.g. licensing for license data).
    struct MetadataRecord {
        // The name associated with the IP.
        string name;
        // A description associated with the IP.
        string description;
        // A keccak-256 hash of the IP content.
        bytes32 hash;
        // The date which the IP was registered.
        uint64 registrationDate;
        // The address of the initial IP registrant.
        address registrant;
        // The token URI associated with the IP.
        string uri;
    }
}
