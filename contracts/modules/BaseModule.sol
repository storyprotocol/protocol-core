// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title BaseModule
/// @notice Base implementation for all modules in Story Protocol. This is to
///         ensure all modules share the same authorization through the access
///         controll manager.
abstract contract BaseModule is IModule {
    /// @notice Gets the protocol-wide module access controller.
    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice Gets the protocol-wide IP asset registry.
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Gets the protocol-wide license registry.
    LicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Modifier for authorizing the calling entity.
    modifier onlyAuthorized(address ipId) {
        _authenticate(ipId);
        _;
    }

    /// @notice Initializes the base module contract.
    /// @param controller The access controller used for IP authorization.
    /// @param assetRegistry The address of the IP asset registry.
    /// @param licenseRegistry The address of the license registry.
    constructor(address controller, address assetRegistry, address licenseRegistry) {
        // TODO: Add checks for interface support or at least zero address
        ACCESS_CONTROLLER = IAccessController(controller);
        IP_ASSET_REGISTRY = IPAssetRegistry(assetRegistry);
        LICENSE_REGISTRY = LicenseRegistry(licenseRegistry);
    }

    /// @notice Gets the protocol string identifier associated with the module.
    /// @return The string identifier of the module.
    function name() public pure virtual override returns (string memory);

    /// @notice Authenticates the caller entity through the access controller.
    function _authenticate(address ipId) internal view {
        try ACCESS_CONTROLLER.checkPermission(ipId, msg.sender, address(this), msg.sig) {
        } catch {
            revert Errors.Module_Unauthorized();
        }
    }
}
