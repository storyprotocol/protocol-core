// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract Governance is AccessControl {
    bytes32 public constant PROTOCOL_ADMIN = bytes32(0);

    constructor(address admin_) {
        if (admin_ == address(0)) revert Errors.Governance__ZeroAddress();
        _grantRole(PROTOCOL_ADMIN, admin_);
    }
}
