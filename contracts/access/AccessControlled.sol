// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IAccessController } from "contracts/interfaces/IAccessController.sol";

contract AccessControlled {

    IAccessController public immutable ACCESS_CONTROLLER;

    constructor(address accessController) {
        ACCESS_CONTROLLER = IAccessController(accessController);
    }

    modifier verifyPermission(address ipAccount) {
        _verifyPermission(ipAccount);
        _;
    }

    function _verifyPermission(address ipAccount) internal view {
        if (msg.sender != ipAccount) {
            // revert if the msg.sender does not have permission
            ACCESS_CONTROLLER.checkPermission(ipAccount, msg.sender, address(this), msg.sig);
        }
    }

    function _hasPermission(address ipAccount) internal view returns (bool) {
        if (msg.sender == ipAccount) {
            return true;
        }
        try ACCESS_CONTROLLER.checkPermission(ipAccount, msg.sender, address(this), msg.sig) {
            return true;
        } catch {
            return false;
        }
    }
}
