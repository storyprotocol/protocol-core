// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;
import { AccessPermission } from "contracts/lib/AccessPermission.sol";

interface IAccessController {
    event PermissionSet(
        address indexed ipAccount,
        address indexed signer,
        address indexed to,
        bytes4 func,
        uint8 permission
    );

    /// @notice Initializes the access controller
    /// @dev This function is called only once during the protocol initialization.
    /// @param ipAccountRegistry The address of the IP account registry
    /// @param moduleRegistry The address of the module registry
    function initialize(address ipAccountRegistry, address moduleRegistry) external;

    /// @notice Sets the permission for a specific function call
    /// @dev Each policy is represented as a mapping from an IP account address to a signer address to a recipient
    /// address to a function selector to a permission level.
    /// The permission level can be 0 (ABSTAIN), 1 (ALLOW), or 2 (DENY).
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient(modules) of the transaction
    /// @param func_ The function selector
    /// @param permission_ The permission level
    function setPermission(address ipAccount_, address signer_, address to_, bytes4 func_, uint8 permission_) external;

    /// @notice Sets a batch of permissions in a single transaction
    /// @dev This function allows setting multiple permissions at once.
    /// @param permissions An array of `Permission` structs, each representing the permission to be set.
    function setBatchPermissions(AccessPermission.Permission[] memory permissions) external;

    /// @notice Sets the permission for all IPAccounts
    /// @dev Only the protocol admin can set the global permission
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient(modules) of the transaction
    /// @param func_ The function selector
    /// @param permission_ The permission level
    function setGlobalPermission(address signer_, address to_, bytes4 func_, uint8 permission_) external;

    /// @notice Gets the permission for a specific function call
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient (modules) of the transaction
    /// @param func_ The function selector
    /// @return The current permission level for the function call
    function getPermission(
        address ipAccount_,
        address signer_,
        address to_,
        bytes4 func_
    ) external view returns (uint8);

    /// @notice Checks the permission for a specific function call
    /// @dev This function checks the permission level for a specific function call.
    /// If a specific permission is set, it overrides the general (wildcard) permission.
    /// If the current level permission is ABSTAIN, the final permission is determined by the upper level.
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient of the transaction
    /// @param func_ The function selector
    function checkPermission(address ipAccount_, address signer_, address to_, bytes4 func_) external view;
}
