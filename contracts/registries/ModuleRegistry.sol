// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IModuleRegistry } from "../interfaces/registries/IModuleRegistry.sol";
import { Errors } from "../lib/Errors.sol";
import { IModule } from "../interfaces/modules/base/IModule.sol";
import { Governable } from "../governance/Governable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { MODULE_TYPE_DEFAULT } from "../lib/modules/Module.sol";

/// @title ModuleRegistry
contract ModuleRegistry is IModuleRegistry, Governable {
    using Strings for *;
    using ERC165Checker for address;

    /// @dev Maps module names to their address.
    mapping(string => address) public modules;

    /// @dev Maps module addresses to their module type name.
    mapping(address => string) public moduleTypes;

    /// @dev All registered module types to their interface id.
    mapping(string => bytes4) public allModuleTypes;

    constructor(address governance) Governable(governance) {
        // Register the default module types
        allModuleTypes[MODULE_TYPE_DEFAULT] = type(IModule).interfaceId;
    }

    /// @notice Registers a new module type in the registry associate with an interface.
    /// @param name The name of the module type to be registered.
    /// @param interfaceId The interface ID associated with the module type.
    function registerModuleType(string memory name, bytes4 interfaceId) external override onlyProtocolAdmin {
        if (interfaceId == 0) {
            revert Errors.ModuleRegistry__InterfaceIdZero();
        }
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }
        if (allModuleTypes[name] != 0) {
            revert Errors.ModuleRegistry__ModuleTypeAlreadyRegistered();
        }
        allModuleTypes[name] = interfaceId;
    }

    /// @notice Removes a module type from the registry.
    /// @param name The name of the module type to be removed.
    function removeModuleType(string memory name) external override onlyProtocolAdmin {
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }
        if (allModuleTypes[name] == 0) {
            revert Errors.ModuleRegistry__ModuleTypeNotRegistered();
        }
        delete allModuleTypes[name];
    }

    /// @notice Registers a new module in the registry with an default module type.
    /// @param name The name of the module to be registered.
    /// @param moduleAddress The address of the module.
    function registerModule(string memory name, address moduleAddress) external onlyProtocolAdmin {
        _registerModule(name, moduleAddress, MODULE_TYPE_DEFAULT);
    }

    /// @notice Registers a new module in the protocol with given module type.
    /// @param name The name of the module.
    /// @param moduleAddress The address of the module.
    /// @param moduleType The type of the module being registered.
    function registerModule(
        string memory name,
        address moduleAddress,
        string memory moduleType
    ) external onlyProtocolAdmin {
        _registerModule(name, moduleAddress, moduleType);
    }

    /// @notice Removes a module from the protocol.
    /// @param name The name of the module to be removed.
    function removeModule(string memory name) external onlyProtocolAdmin {
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }

        if (modules[name] == address(0)) {
            revert Errors.ModuleRegistry__ModuleNotRegistered();
        }

        address module = modules[name];
        delete modules[name];
        delete moduleTypes[module];

        emit ModuleRemoved(name, module);
    }

    /// @notice Returns the address of a module.
    /// @param name The name of the module.
    /// @return The address of the module.
    function getModule(string memory name) external view returns (address) {
        return modules[name];
    }

    /// @notice Checks if a module is registered in the protocol.
    /// @param moduleAddress The address of the module.
    /// @return True if the module is registered, false otherwise.
    function isRegistered(address moduleAddress) external view returns (bool) {
        return bytes(moduleTypes[moduleAddress]).length > 0;
    }

    /// @notice Returns the module type of a given module address.
    /// @param moduleAddress The address of the module.
    /// @return The type of the module as a string.
    function getModuleType(address moduleAddress) external view returns (string memory) {
        return moduleTypes[moduleAddress];
    }

    /// @notice Returns the interface ID associated with a given module type.
    /// @param moduleType The type of the module as a string.
    /// @return The interface ID of the module type as bytes4.
    function getModuleTypeInterfaceId(string memory moduleType) external view returns (bytes4) {
        return allModuleTypes[moduleType];
    }

    // solhint-disable code-complexity
    function _registerModule(string memory name, address moduleAddress, string memory moduleType) internal {
        if (moduleAddress == address(0)) {
            revert Errors.ModuleRegistry__ModuleAddressZeroAddress();
        }
        if (bytes(moduleType).length == 0) {
            revert Errors.ModuleRegistry__ModuleTypeEmptyString();
        }
        if (moduleAddress.code.length == 0) {
            revert Errors.ModuleRegistry__ModuleAddressNotContract();
        }
        if (bytes(moduleTypes[moduleAddress]).length > 0) {
            revert Errors.ModuleRegistry__ModuleAlreadyRegistered();
        }
        if (bytes(name).length == 0) {
            revert Errors.ModuleRegistry__NameEmptyString();
        }
        if (modules[name] != address(0)) {
            revert Errors.ModuleRegistry__NameAlreadyRegistered();
        }
        if (!IModule(moduleAddress).name().equal(name)) {
            revert Errors.ModuleRegistry__NameDoesNotMatch();
        }
        bytes4 moduleTypeInterfaceId = allModuleTypes[moduleType];
        if (moduleTypeInterfaceId == 0) {
            revert Errors.ModuleRegistry__ModuleTypeNotRegistered();
        }
        if (!moduleAddress.supportsInterface(moduleTypeInterfaceId)) {
            revert Errors.ModuleRegistry__ModuleNotSupportExpectedModuleTypeInterfaceId();
        }
        modules[name] = moduleAddress;
        moduleTypes[moduleAddress] = moduleType;

        emit ModuleAdded(name, moduleAddress, moduleTypeInterfaceId, moduleType);
    }
}
