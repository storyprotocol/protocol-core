// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { BaseModule } from "../modules/BaseModule.sol";
import { IResolver } from "../interfaces/resolvers/IResolver.sol";

/// @notice IP Resolver Base Contract
abstract contract ResolverBase is IResolver, BaseModule {
    /// @notice Initializes the base module contract.
    /// @param controller The access controller used for IP authorization.
    /// @param assetRegistry The address of the IP record registry.
    constructor(address controller, address assetRegistry) BaseModule(controller, assetRegistry) {}

    /// @notice Checks whether the resolver interface is supported.
    /// @param id The resolver interface identifier.
    /// @return Whether the resolver interface is supported.
    function supportsInterface(bytes4 id) public view virtual override returns (bool) {
        return id == type(IResolver).interfaceId;
    }
}
