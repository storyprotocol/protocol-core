// SPDX-License-Identifier: BUSDL-1.1
pragma solidity ^0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";

/// @title Mock Module Registry Contract
contract MockModuleRegistry {

    address public immutable REGISTRATION_MODULE;

    constructor(address registrationModule) {
        REGISTRATION_MODULE = registrationModule;
    }

    function protocolModule(string memory moduleKey) external view returns (address module) {
        if (Strings.equal(moduleKey, REGISTRATION_MODULE_KEY)) {
            module = REGISTRATION_MODULE;
        }
    }
}
