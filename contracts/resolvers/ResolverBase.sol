// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { BaseModule } from "../modules/BaseModule.sol";
import { IResolver } from "../interfaces/resolvers/IResolver.sol";
import { AccessControlled } from "../access/AccessControlled.sol";

/// @notice IP Resolver Base Contract
abstract contract ResolverBase is IResolver, BaseModule, AccessControlled {
    constructor(address accessController, address assetRegistry) AccessControlled(accessController, assetRegistry) {}

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 id) public view virtual override(BaseModule, IERC165) returns (bool) {
        return id == type(IResolver).interfaceId || super.supportsInterface(id);
    }
}
