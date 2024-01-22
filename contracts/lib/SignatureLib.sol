// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

/// @title Access Permission Library

library SignatureLib {
    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // computes the hash of a permit
    function getStructHash(Permit memory _permit)
    internal
    pure
    returns (bytes32)
    {
        return
            keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                _permit.owner,
                _permit.spender,
                _permit.value,
                _permit.nonce,
                _permit.deadline
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
    function getTypedDataHash(Permit memory _permit)
    public
    view
    returns (bytes32)
    {
        return
            keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                getStructHash(_permit)
            )
        );
    }
}
