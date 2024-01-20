// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @notice IP Resolver Base Contract
abstract contract ResolverBase is IResolver {

    /// @notice Gets the protocol-wide module access controller.
    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice Checks if IP identified by ipId is authorized to perform a call.
    /// @param ipId The identifier for the IP being authorized.
    modifier onlyAuthorized(address ipId) {
        if (!ACCESS_CONTROLLER.checkPolicy(ipId, msg.sender, address(this), msg.sig)) {
            revert Errors.IPResolver_Unauthorized();
        }
        _;
    }

    /// @notice Initializes the base IP resolver contract.
    /// @param accessController The address of the module access controller.
    constructor(address accessController) {
        ACCESS_CONTROLLER = IAccessController(accessController);
    }

    /// @notice Checks whether the resolver interface is supported.
    /// @param id The resolver interface identifier.
    /// @return Whether the resolver interface is supported.
    function supportsInterface(bytes4 id) public view virtual override returns (bool) {
        return id == type(IResolver).interfaceId;
    }

}
