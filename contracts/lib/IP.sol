// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

/// @title IP Library
/// @notice Library for constants, structs, and helper functions used for IP.
library IP {

    /// @notice List of IP categories currently declared in Story Protocol..
    /// @custom:note Later on this may be canonicalized in the licensing module.
    enum Category {
        PATENT,
        TRADEMARK,
        COPYRIGHT
    }

    /// @notice Core metadata associated with an IP.
    struct Metadata {
        address owner;           // The current owner of the IP.
        string name;             // The name associated with the IP.
        Category category;       // The overarching category the IP belongs to.
        string description;      // A description associated with the IP.
        bytes32 hash;            // A keccak-256 hash of the IP content.
        uint64 registrationDate; // The date which the IP was registered.
        address registrant;      // The address of the initial IP registrant.
        string uri;              // The token URI associated with the IP.
    }

    /// @notice Core metadata exclusively saved by the IP resolver.
    /// @dev Resolved attributes not referenced here are processed through
    ///      their corresponding data modules (e.g. licensing for license data).
    struct MetadataRecord {
        string name;             // The name associated with the IP.
        Category category;       // The overarching category the IP belongs to.
        string description;      // A description associated with the IP.
        bytes32 hash;            // A keccak-256 hash of the IP content.
        uint64 registrationDate; // The date which the IP was registered.
        address registrant;      // The address of the initial IP registrant.
        string uri;              // The token URI associated with the IP.
    }


    /// @notice Converts a custom IP category type to its string representation.
    /// @param category The category of the IP.
    function toString(Category category) internal pure returns (string memory) {
        if (category == Category.PATENT) {
            return "Patent";
        } else if (category  == Category.TRADEMARK) {
            return "Trademark";
        } else {
            return "Copyright";
        }
    }

}
