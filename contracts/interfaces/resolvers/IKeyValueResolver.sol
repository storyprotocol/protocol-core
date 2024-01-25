// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title Key Value Resolver Interface
interface IKeyValueResolver {

    /// @notice Emits when a new key-value pair is set for the resolver.
    event KeyValueSet(
        address indexed ipId,
        string indexed key,
        string value
    );

    /// @notice Retrieves the string value associated with a key for an IP asset.
    function value(
        address ipId,
        string calldata key
    ) external view returns (string memory);
}
