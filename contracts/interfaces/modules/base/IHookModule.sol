// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IModule } from "./IModule.sol";

/// @notice Hook Module Interface
interface IHookModule is IModule {
    /// @notice Verify if the caller is qualified
    function verify(address caller, bytes calldata data) external returns (bool);
    /// @notice Validates the configuration for the hook.
    /// @param configData The configuration data for the hook.
    function validateConfig(bytes calldata configData) external view;
}
