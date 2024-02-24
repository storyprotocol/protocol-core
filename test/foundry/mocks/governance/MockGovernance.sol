// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { IGovernance } from "../../../../contracts/interfaces/governance/IGovernance.sol";
import { GovernanceLib } from "../../../../contracts/lib/GovernanceLib.sol";

contract MockGovernance is AccessControl, IGovernance {
    GovernanceLib.ProtocolState internal state;

    constructor(address admin) {
        _grantRole(GovernanceLib.PROTOCOL_ADMIN, admin);
    }

    function setState(GovernanceLib.ProtocolState newState) external {
        state = newState;
    }

    function getState() external view returns (GovernanceLib.ProtocolState) {
        return state;
    }

    function supportsInterface(bytes4) public pure override returns (bool) {
        return true;
    }
}
