// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ResolverBase } from "./ResolverBase.sol";
import { KeyValueResolver } from "../resolvers/KeyValueResolver.sol";
import { IP_RESOLVER_MODULE_KEY } from "../lib/modules/Module.sol";

/// @title IP Resolver
/// @notice Canonical IP resolver contract used for Story Protocol.
/// TODO: Add support for interface resolvers, where one can add a contract
///        and supported interface (address, interfaceId) to tie to an IP asset.
/// TODO: Add support for multicall, so multiple records may be set at once.
contract IPResolver is KeyValueResolver {
    string public constant override name = IP_RESOLVER_MODULE_KEY;

    constructor(address accessController, address ipAssetRegistry) ResolverBase(accessController, ipAssetRegistry) {}

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 id) public view virtual override returns (bool) {
        return super.supportsInterface(id);
    }
}
