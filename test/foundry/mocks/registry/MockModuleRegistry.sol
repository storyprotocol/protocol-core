// SPDX-License-Identifier: BUSDL-1.1
pragma solidity 0.8.23;

import { IModuleRegistry } from "../../../../contracts/interfaces/registries/IModuleRegistry.sol";
import { MODULE_TYPE_DEFAULT } from "../../../../contracts/lib/modules/Module.sol";

contract MockModuleRegistry is IModuleRegistry {
    mapping(string => address) public modules;
    mapping(address => string) public moduleTypes;
    mapping(string => bytes4) public allModuleTypes;

    function registerModuleType(string memory name, bytes4 interfaceId) external override {
        allModuleTypes[name] = interfaceId;
    }

    function removeModuleType(string memory name) external override {
        delete allModuleTypes[name];
    }

    function registerModule(string memory name, address moduleAddress) external {
        _registerModule(name, moduleAddress, MODULE_TYPE_DEFAULT);
    }

    function registerModule(string memory name, address moduleAddress, string memory moduleType) external {
        _registerModule(name, moduleAddress, moduleType);
    }

    function removeModule(string memory name) external {
        address module = modules[name];
        delete modules[name];
        delete moduleTypes[module];

        emit ModuleRemoved(name, module);
    }

    function getModule(string memory name) external view returns (address) {
        return modules[name];
    }

    function isRegistered(address moduleAddress) external view returns (bool) {
        return bytes(moduleTypes[moduleAddress]).length > 0;
    }

    function getModuleType(address moduleAddress) external view returns (string memory) {
        return moduleTypes[moduleAddress];
    }

    function getModuleTypeInterfaceId(string memory moduleType) external view returns (bytes4) {
        return allModuleTypes[moduleType];
    }

    function _registerModule(string memory name, address moduleAddress, string memory moduleType) internal {
        modules[name] = moduleAddress;
        moduleTypes[moduleAddress] = moduleType;
    }
}
