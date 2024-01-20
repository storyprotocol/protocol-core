// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @notice IP Resolver Base Contract
abstract contract ResolverBase is IResolver {
    /// @notice Gets the protocol-wide module access controller.
    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice Gets the protocol-wide IP account registry.
    IPAccountRegistry public immutable IP_ACCOUNT_REGISTRY;

    /// @notice Gets the protocol-wide IP record registry.
    IPRecordRegistry public immutable IP_RECORD_REGISTRY;

    /// @notice Checks if IP identified by ipId is authorized to perform a call.
    /// @param ipId The identifier for the IP being authorized.
    modifier onlyAuthorized(address ipId) {
        if (!ACCESS_CONTROLLER.checkPermission(ipId, msg.sender, address(this), msg.sig)) {
            revert Errors.IPResolver_Unauthorized();
        }
        _;
    }

    /// @notice Initializes the base IP resolver contract.
    /// @param controller The address of the module access controller.
    /// @param recordRegistry The address of the IP record registry.
    /// @param accountRegistry The address of the IP account registry.
    constructor(address controller, address recordRegistry, address accountRegistry) {
        ACCESS_CONTROLLER = IAccessController(controller);
        IP_RECORD_REGISTRY = IPRecordRegistry(recordRegistry);
        IP_ACCOUNT_REGISTRY = IPAccountRegistry(accountRegistry);
    }

    /// @notice Gets the access controller responsible for resolver auth.
    /// @return The address of the access controller.
    function accessController() external view returns (address) {
        return address(ACCESS_CONTROLLER);
    }

    /// @notice Checks whether the resolver interface is supported.
    /// @param id The resolver interface identifier.
    /// @return Whether the resolver interface is supported.
    function supportsInterface(bytes4 id) public view virtual override returns (bool) {
        return id == type(IResolver).interfaceId;
    }
}
