// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

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
