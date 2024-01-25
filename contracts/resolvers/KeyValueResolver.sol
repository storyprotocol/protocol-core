// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IKeyValueResolver } from "contracts/interfaces/resolvers/IKeyValueResolver.sol";
import { ResolverBase } from "contracts/resolvers/ResolverBase.sol";

/// @title Key Value Resolver
/// @notice Resolver used for returning values associated with keys. This is the
///         preferred approach for adding additional attribution to IP that the
///         IP originator thinks is beneficial to have on chain.
abstract contract KeyValueResolver is IKeyValueResolver, ResolverBase {

    /// @dev Stores key-value pairs associated with the IP.
    mapping(string => string) _values;

    /// @notice Sets the string value for a specified key of an IP ID.
    /// @param ipId The canonical identifier of the IP asset.
    /// @param k The string parameter key to update.
    /// @param v The value to set for the specified key.
    function setValue(
        address ipId,
        string calldata k,
        string calldata v
    ) external virtual onlyAuthorized(ipId) returns (string memory) {
        _values[k] = v;
        emit KeyValueSet(ipId, k, v);
    }

    /// @notice Retrieves the string value associated with a key for an IP asset.
    /// @param k The string parameter key to query.
    function value(
        address ipId,
        string calldata k
    ) external view virtual returns (string memory) {
        return _values[k];
    }

    /// @notice Checks whether the resolver interface is supported.
    /// @param id The resolver interface identifier.
    /// @return Whether the resolver interface is supported.
    function supportsInterface(bytes4 id) public view virtual override returns (bool) {
        return id == type(IKeyValueResolver).interfaceId || super.supportsInterface(id);
    }
}
