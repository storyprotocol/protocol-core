// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title IModuleRegistry
/// @dev This interface defines the methods for a module registry in the Story Protocol.
interface IModuleRegistry {
    /// @notice Emitted when a new module is added to the registry.
    /// @param name The name of the module.
    /// @param module The address of the module.
    event ModuleAdded(string name, address indexed module, bytes4 indexed moduleTypeInterfaceId, string moduleType);

    /// @notice Emitted when a module is removed from the registry.
    /// @param name The name of the module.
    /// @param module The address of the module.
    event ModuleRemoved(string name, address indexed module);

    /// @notice Registers a new module type in the registry associate with an interface.
    /// @param name The name of the module type to be registered.
    /// @param interfaceId The interface ID associated with the module type.
    function registerModuleType(string memory name, bytes4 interfaceId) external;

    /// @notice Removes a module type from the registry.
    /// @param name The name of the module type to be removed.
    function removeModuleType(string memory name) external;

    /// @notice Registers a new module in the registry.
    /// @dev This function can only be called by the owner of the registry.
    /// @param name The name of the module.
    /// @param moduleAddress The address of the module.
    function registerModule(string memory name, address moduleAddress) external;

    /// @notice Registers a new module in the registry with an associated module type.
    /// @param name The name of the module to be registered.
    /// @param moduleAddress The address of the module.
    /// @param moduleType The type of the module being registered.
    function registerModule(string memory name, address moduleAddress, string memory moduleType) external;

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

    /// @notice Returns the module type of a given module address.
    /// @param moduleAddress The address of the module.
    /// @return The type of the module as a string.
    function getModuleType(address moduleAddress) external view returns (string memory);

    /// @notice Returns the interface ID associated with a given module type.
    /// @param moduleType The type of the module as a string.
    /// @return The interface ID of the module type as bytes4.
    function getModuleTypeInterfaceId(string memory moduleType) external view returns (bytes4);
}
