// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title Key Value Resolver Interface
interface IKeyValueResolver {
    /// @notice Emits when a new key-value pair is set for the resolver.
    event KeyValueSet(address indexed ipId, string indexed key, string value);

    /// @notice Sets the string value for a specified key of an IP ID.
    /// @dev Enforced to be only callable by users with valid permission to call on behalf of the ipId.
    /// @param ipId The canonical identifier of the IP asset.
    /// @param key The string parameter key to update.
    /// @param val The value to set for the specified key.
    function setValue(address ipId, string calldata key, string calldata val) external;

    /// @notice Retrieves the string value associated with a key for an IP asset.
    /// @param key The string parameter key to query.
    /// @return value The value associated with the specified key.
    function value(address ipId, string calldata key) external view returns (string memory);
}
