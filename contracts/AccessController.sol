// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Governable } from "contracts/governance/Governable.sol";

/// @title AccessController
/// @dev This contract is used to control access permissions for different function calls in the protocol.
/// It allows setting permissions for specific function calls, checking permissions, and initializing the contract.
/// The contract uses a mapping to store policies, which are represented as a nested mapping structure.
/// The contract also interacts with other contracts such as IIPAccountRegistry, IModuleRegistry, and IIPAccount.
///
/// Each policy is represented as a mapping from an IP account address to a signer address to a recipient
/// address to a function selector to a permission level.
/// The permission level can be 0 (ABSTAIN), 1 (ALLOW), or 2 (DENY).
///
/// The contract includes the following functions:
/// - initialize: Sets the addresses of the IP account registry and the module registry.
/// - setPermission: Sets the permission for a specific function call.
/// - getPermission: Returns the permission level for a specific function call.
/// - checkPermission: Checks if a specific function call is allowed.
contract AccessController is IAccessController, Governable {
    using IPAccountChecker for IIPAccountRegistry;

    address public IP_ACCOUNT_REGISTRY;
    address public MODULE_REGISTRY;

    mapping(address => mapping(address => mapping(address => mapping(bytes4 => uint8)))) public permissions;

    constructor(address governance) Governable(governance) {}

    function initialize(address ipAccountRegistry, address moduleRegistry) external onlyProtocolAdmin {
        IP_ACCOUNT_REGISTRY = ipAccountRegistry;
        MODULE_REGISTRY = moduleRegistry;
    }

    /// @notice Sets the permission for all IPAccounts
    function setGlobalPermission(
        address signer_,
        address to_,
        bytes4 func_,
        uint8 permission_
    ) external onlyProtocolAdmin {
        if (signer_ == address(0)) {
            revert Errors.AccessController__SignerIsZeroAddress();
        }
        // permission must be one of ABSTAIN, ALLOW, DENY
        if (permission_ > 2) {
            revert Errors.AccessController__PermissionIsNotValid();
        }
        permissions[address(0)][signer_][to_][func_] = permission_;
    }

    /// @notice Sets the permission for a specific function call
    /// @dev By default, all policies are set to ABSTAIN, which means that the permission is not set
    /// Owner of ipAccount by default has permission sets the permission
    /// permission 0 => ABSTAIN, 1 => ALLOW, 3 => DENY
    /// address(0) => wildcard
    /// bytes4(0) => wildcard
    /// specific permission overrides wildcard permission
    /// @param ipAccount_ The account that owns the IP (not support wildcard permission)
    /// @param signer_ The account that signs the transaction (not support wildcard permission)
    /// @param to_ The recipient of the transaction (support wildcard permission)
    /// @param func_ The function selector (support wildcard permission)
    /// @param permission_ The permission level (0 => ABSTAIN, 1 => ALLOW, 3 => DENY)
    function setPermission(
        address ipAccount_,
        address signer_,
        address to_,
        bytes4 func_,
        uint8 permission_
    ) external whenNotPaused {
        // IPAccount and signer does not support wildcard permission
        if (ipAccount_ == address(0)) {
            revert Errors.AccessController__IPAccountIsZeroAddress();
        }
        if (signer_ == address(0)) {
            revert Errors.AccessController__SignerIsZeroAddress();
        }
        if (!IIPAccountRegistry(IP_ACCOUNT_REGISTRY).isIpAccount(ipAccount_)) {
            revert Errors.AccessController__IPAccountIsNotValid();
        }
        // permission must be one of ABSTAIN, ALLOW, DENY
        if (permission_ > 2) {
            revert Errors.AccessController__PermissionIsNotValid();
        }
        if (!IModuleRegistry(MODULE_REGISTRY).isRegistered(msg.sender) && ipAccount_ != msg.sender) {
            revert Errors.AccessController__CallerIsNotIPAccount();
        }
        permissions[ipAccount_][signer_][to_][func_] = permission_;

        emit PermissionSet(ipAccount_, signer_, to_, func_, permission_);
    }

    /// @notice Returns the permission level for a specific function call.
    /// @param ipAccount_ The account that owns the IP.
    /// @param signer_ The account that signs the transaction.
    /// @param to_ The recipient of the transaction.
    /// @param func_ The function selector.
    /// @return The permission level for the specific function call.
    function getPermission(
        address ipAccount_,
        address signer_,
        address to_,
        bytes4 func_
    ) external view returns (uint8) {
        return permissions[ipAccount_][signer_][to_][func_];
    }

    /// @notice Checks if a specific function call is allowed.
    /// @dev This function checks the permission level for a specific function call.
    /// If a specific permission is set, it overrides the general (wildcard) permission.
    /// If the current level permission is ABSTAIN, the final permission is determined by the upper level.
    /// @param ipAccount_ The account that owns the IP.
    /// @param signer_ The account that signs the transaction.
    /// @param to_ The recipient of the transaction.
    /// @param func_ The function selector.
    /// @return True if the function call is allowed, false otherwise.
    // solhint-disable code-complexity
    function checkPermission(
        address ipAccount_,
        address signer_,
        address to_,
        bytes4 func_
    ) external view whenNotPaused returns (bool) {
        // ipAccount_ can only call registered modules or set Permissions
        if (to_ != address(this) && !IModuleRegistry(MODULE_REGISTRY).isRegistered(to_)) {
            return false;
        }
        // Must be a valid IPAccount
        if (!IIPAccountRegistry(IP_ACCOUNT_REGISTRY).isIpAccount(ipAccount_)) {
            return false;
        }
        // Owner can call all functions of all modules
        if (IIPAccount(payable(ipAccount_)).owner() == signer_) {
            return true;
        }

        // Specific function permission overrides wildcard/general permission
        if (permissions[ipAccount_][signer_][to_][func_] == AccessPermission.ALLOW) {
            return true;
        }

        // If specific function permission is ABSTAIN, check module level permission
        if (permissions[ipAccount_][signer_][to_][func_] == AccessPermission.ABSTAIN) {
            // Return true if allow to call all functions of the module
            if (permissions[ipAccount_][signer_][to_][bytes4(0)] == AccessPermission.ALLOW) {
                return true;
            }
            // If module level permission is ABSTAIN, check transaction signer level permission
            if (permissions[ipAccount_][signer_][to_][bytes4(0)] == AccessPermission.ABSTAIN) {
                if (permissions[address(0)][signer_][to_][func_] == AccessPermission.ALLOW) {
                    return true;
                }
                // Return true if the ipAccount allow the signer can call all functions of all modules
                // Otherwise, return false
                return permissions[ipAccount_][signer_][address(0)][bytes4(0)] == AccessPermission.ALLOW;
            }
            return false;
        }
        return false;
    }
}
