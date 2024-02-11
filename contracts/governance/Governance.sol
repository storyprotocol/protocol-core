// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { Errors } from "../lib/Errors.sol";
import { IGovernance } from "../interfaces/governance/IGovernance.sol";
import { GovernanceLib } from "../lib/GovernanceLib.sol";

/// @title Governance
/// @dev This contract is used for governance of the protocol.
/// TODO: Replace with OZ's 2StepOwnable
contract Governance is AccessControl, IGovernance {
    GovernanceLib.ProtocolState internal state;

    /// @notice Creates a new Governance contract.
    /// @param admin The address of the initial admin.
    constructor(address admin) {
        if (admin == address(0)) revert Errors.Governance__ZeroAddress();
        _grantRole(GovernanceLib.PROTOCOL_ADMIN, admin);
    }

    /// @notice Sets the state of the protocol.
    /// @param newState The new state of the protocol.
    function setState(GovernanceLib.ProtocolState newState) external override {
        if (!hasRole(GovernanceLib.PROTOCOL_ADMIN, msg.sender)) revert Errors.Governance__OnlyProtocolAdmin();
        if (newState == state) revert Errors.Governance__NewStateIsTheSameWithOldState();
        emit StateSet(msg.sender, state, newState, block.timestamp);
        state = newState;
    }

    /// @notice Returns the current state of the protocol.
    /// @return The current state of the protocol.
    function getState() external view override returns (GovernanceLib.ProtocolState) {
        return state;
    }

    /// @notice Checks if the contract supports a specific interface.
    /// @param interfaceId The id of the interface.
    /// @return True if the contract supports the interface, false otherwise.
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return (interfaceId == type(IGovernance).interfaceId || super.supportsInterface(interfaceId));
    }
}
