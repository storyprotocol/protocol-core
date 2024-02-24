// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity 0.8.23;

/// @notice Resolver Interface
interface IResolver {
    /// @notice Checks whether the resolver IP interface is supported.
    function supportsInterface(bytes4 id) external view returns (bool);
}
