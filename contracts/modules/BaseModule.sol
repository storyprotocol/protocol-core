// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IModule } from "../interfaces/modules/base/IModule.sol";
import { AccessControlled } from "../access/AccessControlled.sol";
import { IPAssetRegistry } from "../registries/IPAssetRegistry.sol";

/// @title BaseModule
/// @notice Base implementation for all modules in Story Protocol. This is to
///         ensure all modules share the same authorization through the access
///         controll manager.
abstract contract BaseModule is IModule, AccessControlled {
    /// @notice Gets the protocol-wide IP asset registry.
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;

    /// @notice Initializes the base module contract.
    /// @param accessController The access controller used for IP authorization.
    /// @param ipAssetRegistry The address of the IP asset registry.
    constructor(address accessController, address ipAssetRegistry) AccessControlled(accessController, ipAssetRegistry) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
    }
}
