// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IModuleRegistry } from "../interfaces/registries/IModuleRegistry.sol";
import { Errors } from "../lib/Errors.sol";
import { IModule } from "../interfaces/modules/base/IModule.sol";
import { Governable } from "../governance/Governable.sol";

/// @title ModuleRegistry
contract ModuleRegistry is IModuleRegistry, Governable {
    using Strings for *;

    mapping(string => address) public _modules;
    mapping(address => bool) public _isModule;

    constructor(address governance) Governable(governance) {}

    /// @notice Registers a new module in the protocol.
    /// @param name The name of the module.
    /// @param moduleAddress The address of the module.
    function registerModule(string memory name, address moduleAddress) external onlyProtocolAdmin {
        // TODO: check can only called by protocol admin
        if (moduleAddress == address(0)) {
            revert Errors.ModuleRegistry__ModuleAddressZeroAddress();
        }
        if (moduleAddress.code.length == 0) {
            revert Errors.ModuleRegistry__ModuleAddressNotContract();
        }
        if (_isModule[moduleAddress]) {
            revert Errors.ModuleRegistry__ModuleAlreadyRegistered();
        }
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }
        if (_modules[name] != address(0)) {
            revert Errors.ModuleRegistry__NameAlreadyRegistered();
        }
        if (!IModule(moduleAddress).name().equal(name)) {
            revert Errors.ModuleRegistry__NameDoesNotMatch();
        }
        _modules[name] = moduleAddress;
        _isModule[moduleAddress] = true;

        emit ModuleAdded(name, moduleAddress);
    }

    /// @notice Removes a module from the protocol.
    /// @param name The name of the module to be removed.
    function removeModule(string memory name) external onlyProtocolAdmin {
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }

        if (_modules[name] == address(0)) {
            revert Errors.ModuleRegistry__ModuleNotRegistered();
        }

        address module = _modules[name];
        delete _modules[name];
        delete _isModule[module];

        emit ModuleRemoved(name, module);
    }

    /// @notice Returns the address of a module.
    /// @param name The name of the module.
    /// @return The address of the module.
    function getModule(string memory name) external view returns (address) {
        return _modules[name];
    }

    /// @notice Checks if a module is registered in the protocol.
    /// @param moduleAddress The address of the module.
    /// @return True if the module is registered, false otherwise.
    function isRegistered(address moduleAddress) external view returns (bool) {
        return _isModule[moduleAddress];
    }
}
