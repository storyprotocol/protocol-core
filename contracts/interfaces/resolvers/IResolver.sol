// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

/// @notice Resolver Interface
interface IResolver {

    /// @notice Gets the address of the access controller for the resolver.
    function accessController() view external returns (address);

    /// @notice Checks whether the resolver IP interface is supported.
    function supportsInterface(bytes4 id) view external returns (bool);

}
