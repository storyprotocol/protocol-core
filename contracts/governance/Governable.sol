// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { Errors } from "../lib/Errors.sol";
import { IGovernance } from "../interfaces/governance/IGovernance.sol";
import { IGovernable } from "../interfaces/governance/IGovernable.sol";
import { GovernanceLib } from "../lib/GovernanceLib.sol";

/// @title Governable
/// @dev All contracts managed by governance should inherit from this contract.
abstract contract Governable is IGovernable {
    /// @notice The address of the governance.
    address public governance;

    /// @dev Ensures that the function is called by the protocol admin.
    modifier onlyProtocolAdmin() {
        if (!IGovernance(governance).hasRole(GovernanceLib.PROTOCOL_ADMIN, msg.sender)) {
            revert Errors.Governance__OnlyProtocolAdmin();
        }
        _;
    }

    modifier whenNotPaused() {
        if (IGovernance(governance).getState() == GovernanceLib.ProtocolState.Paused) {
            revert Errors.Governance__ProtocolPaused();
        }
        _;
    }

    /// @notice Constructs a new Governable contract.
    /// @param governance_ The address of the governance.
    constructor(address governance_) {
        if (governance_ == address(0)) revert Errors.Governance__ZeroAddress();
        governance = governance_;
        emit GovernanceUpdated(governance);
    }

    /// @notice Sets a new governance address.
    /// @param newGovernance The address of the new governance.
    function setGovernance(address newGovernance) external onlyProtocolAdmin {
        if (newGovernance == address(0)) revert Errors.Governance__ZeroAddress();
        if (!ERC165Checker.supportsInterface(newGovernance, type(IGovernance).interfaceId))
            revert Errors.Governance__UnsupportedInterface("IGovernance");
        if (IGovernance(newGovernance).getState() != IGovernance(governance).getState())
            revert Errors.Governance__InconsistentState();
        governance = newGovernance;
        emit GovernanceUpdated(newGovernance);
    }

    /// @notice Returns the current governance address.
    /// @return governance The address of the current governance.
    function getGovernance() external view returns (address) {
        return governance;
    }
}
