// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @notice Resolver Interface
interface IResolver {
    /// @notice Checks whether the resolver IP interface is supported.
    function supportsInterface(bytes4 id) external view returns (bool);
}
