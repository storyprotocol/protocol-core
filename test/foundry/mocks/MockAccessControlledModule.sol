// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/interfaces/modules/base/IModule.sol";
import "contracts/interfaces/registries/IIPAccountRegistry.sol";
import "contracts/lib/registries/IPAccountChecker.sol";
import "contracts/interfaces/registries/IModuleRegistry.sol";
import "contracts/access/AccessControlled.sol";

contract MockAccessControlledModule is IModule, AccessControlled {
    using IPAccountChecker for IIPAccountRegistry;

    IModuleRegistry public moduleRegistry;
    string public name;

    constructor(
        address accessController,
        address ipAccountRegistry,
        address moduleRegistry_,
        string memory _name
    ) AccessControlled(accessController, ipAccountRegistry) {
        moduleRegistry = IModuleRegistry(moduleRegistry_);
        name = _name;
    }

    function onlyIpAccountFunction(
        string memory param,
        bool success
    ) external view onlyIpAccount returns (string memory) {
        if (!success) {
            revert("expected failure");
        }
        return param;
    }

    function ipAccountOrPermissionFunction(
        address ipAccount,
        string memory param,
        bool success
    ) external view verifyPermission(ipAccount) returns (string memory) {
        if (!success) {
            revert("expected failure");
        }
        return param;
    }

    function customizedFunction(
        address ipAccount,
        string memory param,
        bool success
    ) external view returns (string memory) {
        if (!_hasPermission(ipAccount)) {
            revert("expected permission check failure");
        }
        if (!success) {
            revert("expected failure");
        }
        return param;
    }

}
