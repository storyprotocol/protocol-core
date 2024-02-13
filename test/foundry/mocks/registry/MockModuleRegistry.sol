// SPDX-License-Identifier: BUSDL-1.1
pragma solidity ^0.8.23;

import { IModuleRegistry } from "../../../../contracts/interfaces/registries/IModuleRegistry.sol";

contract MockModuleRegistry is IModuleRegistry {
    mapping(string => address) public _modules;
    mapping(address => bool) public _isModule;

    function registerModule(string memory name, address moduleAddress) external {
        _modules[name] = moduleAddress;
        _isModule[moduleAddress] = true;
    }

    function removeModule(string memory name) external {
        address module = _modules[name];
        delete _modules[name];
        delete _isModule[module];
    }

    function getModule(string memory name) external view returns (address) {
        return _modules[name];
    }

    function isRegistered(address moduleAddress) external view returns (bool) {
        return _isModule[moduleAddress];
    }
}
