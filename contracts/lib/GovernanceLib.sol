// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title Governance
/// @dev This library provides types for Story Protocol Governance.
library GovernanceLib {
    bytes32 public constant PROTOCOL_ADMIN = bytes32(0);

    /// @notice An enum containing the different states the protocol can be in.
    /// @param Unpaused The unpaused state.
    /// @param Paused The paused state.
    enum ProtocolState {
        Unpaused,
        Paused
    }
}
