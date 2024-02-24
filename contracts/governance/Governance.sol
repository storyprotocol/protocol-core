// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { Errors } from "../lib/Errors.sol";
import { IGovernance } from "../interfaces/governance/IGovernance.sol";
import { GovernanceLib } from "../lib/GovernanceLib.sol";

/// @title Governance
/// @dev This contract is used for governance of the protocol.
/// TODO: Replace with OZ's 2StepOwnable
contract Governance is AccessControl, IGovernance {
    /// @dev The current governance state.
    GovernanceLib.ProtocolState internal state;

    /// @notice Creates a new Governance contract.
    /// @param admin The address of the initial admin.
    constructor(address admin) {
        if (admin == address(0)) revert Errors.Governance__ZeroAddress();
        _grantRole(GovernanceLib.PROTOCOL_ADMIN, admin);
    }

    /// @notice Sets the state of the protocol
    /// @dev This function can only be called by an account with the appropriate role
    /// @param newState The new state to set for the protocol
    function setState(GovernanceLib.ProtocolState newState) external override {
        if (!hasRole(GovernanceLib.PROTOCOL_ADMIN, msg.sender)) revert Errors.Governance__OnlyProtocolAdmin();
        if (newState == state) revert Errors.Governance__NewStateIsTheSameWithOldState();
        emit StateSet(msg.sender, state, newState, block.timestamp);
        state = newState;
    }

    /// @notice Returns the current state of the protocol
    /// @return state The current state of the protocol
    function getState() external view override returns (GovernanceLib.ProtocolState) {
        return state;
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return (interfaceId == type(IGovernance).interfaceId || super.supportsInterface(interfaceId));
    }
}
