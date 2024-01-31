// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @notice Module Interface
interface IModule {
    /// @notice Returns the string identifier associated with the module.
    function name() external returns (string memory);
}
