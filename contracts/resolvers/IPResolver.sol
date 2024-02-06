// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IResolver } from "../interfaces/resolvers/IResolver.sol";
import { ResolverBase } from "./ResolverBase.sol";
import { BaseModule } from "../modules/BaseModule.sol";
import { IModule } from "../interfaces/modules/base/IModule.sol";
import { IKeyValueResolver } from "../interfaces/resolvers/IKeyValueResolver.sol";
import { IIPAccount } from "../interfaces/IIPAccount.sol";
import { KeyValueResolver } from "../resolvers/KeyValueResolver.sol";
import { Errors } from "../lib/Errors.sol";
import { IP } from "../lib/IP.sol";
import { IP_RESOLVER_MODULE_KEY } from "../lib/modules/Module.sol";

/// @title IP Resolver
/// @notice Canonical IP resolver contract used for Story Protocol.
/// TODO: Add support for interface resolvers, where one can add a contract
///        and supported interface (address, interfaceId) to tie to an IP asset.
/// TODO: Add support for multicall, so multiple records may be set at once.
contract IPResolver is KeyValueResolver {
    /// @notice Initializes the IP metadata resolver.
    /// @param accessController The access controller used for IP authorization.
    /// @param ipAssetRegistry The address of the IP record registry.
    /// @param licenseRegistry The address of the license registry.
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licenseRegistry
    ) ResolverBase(accessController, ipAssetRegistry, licenseRegistry) {}

    /// @notice Checks whether the resolver interface is supported.
    /// @param id The resolver interface identifier.
    /// @return Whether the resolver interface is supported.
    function supportsInterface(bytes4 id) public view virtual override returns (bool) {
        return super.supportsInterface(id);
    }

    /// @notice Gets the protocol-wide module identifier for this module.
    function name() public pure override(BaseModule, IModule) returns (string memory) {
        return IP_RESOLVER_MODULE_KEY;
    }
}
