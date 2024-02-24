// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { GovernanceLib } from "../../lib/GovernanceLib.sol";

/// @title IGovernance
/// @dev This interface defines the governance functionality for the protocol.
interface IGovernance is IAccessControl {
    /// @notice Emitted when the protocol state is set
    /// @param account The address that triggered the state change
    /// @param prevState The previous state of the protocol
    /// @param newState The new state of the protocol
    /// @param timestamp The time when the state change occurred
    event StateSet(
        address indexed account,
        GovernanceLib.ProtocolState prevState,
        GovernanceLib.ProtocolState newState,
        uint256 timestamp
    );

    /// @notice Sets the state of the protocol
    /// @dev This function can only be called by an account with the appropriate role
    /// @param newState The new state to set for the protocol
    function setState(GovernanceLib.ProtocolState newState) external;

    /// @notice Returns the current state of the protocol
    /// @return state The current state of the protocol
    function getState() external view returns (GovernanceLib.ProtocolState);
}
