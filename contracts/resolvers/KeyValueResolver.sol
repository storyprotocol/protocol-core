// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IKeyValueResolver } from "../interfaces/resolvers/IKeyValueResolver.sol";
import { ResolverBase } from "../resolvers/ResolverBase.sol";

/// @title Key Value Resolver
/// @notice Resolver used for returning values associated with keys. This is the
///         preferred approach for adding additional attribution to IP that the
///         IP originator thinks is beneficial to have on chain.
abstract contract KeyValueResolver is IKeyValueResolver, ResolverBase {
    /// @dev Stores key-value pairs associated with each IP.
    mapping(address => mapping(string => string)) internal _values;

    /// @notice Sets the string value for a specified key of an IP ID.
    /// @dev Enforced to be only callable by users with valid permission to call on behalf of the ipId.
    /// @param ipId The canonical identifier of the IP asset.
    /// @param key The string parameter key to update.
    /// @param val The value to set for the specified key.
    function setValue(address ipId, string calldata key, string calldata val) external virtual verifyPermission(ipId) {
        _values[ipId][key] = val;
        emit KeyValueSet(ipId, key, val);
    }

    /// @notice Retrieves the string value associated with a key for an IP asset.
    /// @param key The string parameter key to query.
    /// @return value The value associated with the specified key.
    function value(address ipId, string calldata key) external view virtual returns (string memory) {
        return _values[ipId][key];
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 id) public view virtual override returns (bool) {
        return id == type(IKeyValueResolver).interfaceId || super.supportsInterface(id);
    }
}
