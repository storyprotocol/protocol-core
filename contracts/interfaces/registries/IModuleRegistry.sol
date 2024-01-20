// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

/// @title IModuleRegistry
/// @dev This interface defines the methods for a module registry in the Story Protocol.
interface IModuleRegistry {
    /// @notice Emitted when a new module is added to the registry.
    /// @param name The name of the module.
    /// @param module The address of the module.
    event ModuleAdded(string indexed name, address indexed module);

    /// @notice Emitted when a module is removed from the registry.
    /// @param name The name of the module.
    /// @param module The address of the module.
    event ModuleRemoved(string indexed name, address indexed module);

    /// @notice Registers a new module in the registry.
    /// @dev This function can only be called by the owner of the registry.
    /// @param name The name of the module.
    /// @param moduleAddress The address of the module.
    function registerModule(string memory name, address moduleAddress) external;

    /// @notice Removes a module from the registry.
    /// @dev This function can only be called by the owner of the registry.
    /// @param name The name of the module.
    function removeModule(string memory name) external;

    /// @notice Returns the address of a module by its name.
    /// @param name The name of the module.
    /// @return The address of the module.
    function getModule(string memory name) external view returns (address);

    /// @notice Checks if a module is registered in the registry.
    /// @param moduleAddress The address of the module.
    /// @return A boolean indicating whether the module is registered.
    function isRegistered(address moduleAddress) external view returns (bool);
}
