// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IIPAccountRegistry } from "../../interfaces/registries/IIPAccountRegistry.sol";
import { ITokenManagementModule } from "../../interfaces/modules/external/ITokenManagementModule.sol";
import { IPAccountChecker } from "../../lib/registries/IPAccountChecker.sol";
import { TOKEN_MANAGEMENT_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";

/// @title Token Management Module
/// @notice Module for transferring ERC20, ERC721, and ERC1155 tokens for IP Accounts.
/// @dev SECURITY RISK: An IPAccount can delegate to a frontend contract (not a registered module) to transfer tokens
/// on behalf of the IPAccount via the Token Management Module. This frontend contract can transfer any tokens that are
/// approved by the IPAccount for the Token Management Module. In other words, there's no mechanism for this module to
/// granularly control which token a caller (approved contract in this case) can transfer.
contract TokenManagementModule is AccessControlled, BaseModule, ITokenManagementModule {
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;

    string public constant override name = TOKEN_MANAGEMENT_MODULE_KEY;

    constructor(
        address accessController,
        address ipAccountRegistry
    ) AccessControlled(accessController, ipAccountRegistry) {}

    /// @notice Transfers ERC20 token from the IP account to the specified recipient.
    /// @dev When calling this function, the caller must have the permission to call `transfer` via the IP account.
    /// @dev Does not support transfer of multiple tokens at once.
    /// @param ipAccount The IP account to transfer the ERC20 token from
    /// @param to The recipient of the token
    /// @param tokenContract The address of the ERC20 token contract
    /// @param amount The amount of token to transfer
    function transferERC20(
        address payable ipAccount,
        address to,
        address tokenContract,
        uint256 amount
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
    }

    /// @notice Transfers ERC721 token from the IP account to the specified recipient.
    /// @dev When calling this function, the caller must have the permission to call `transferFrom` via the IP account.
    /// @dev Does not support batch transfers.
    /// @param ipAccount The IP account to transfer the ERC721 token from
    /// @param to The recipient of the token
    /// @param tokenContract The address of the ERC721 token contract
    /// @param tokenId The ID of the token to transfer
    function transferERC721(
        address payable ipAccount,
        address to,
        address tokenContract,
        uint256 tokenId
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", ipAccount, to, tokenId)
        );
    }

    /// @notice Transfers ERC1155 token from the IP account to the specified recipient.
    /// @dev When calling this function, the caller must have the permission to call `safeTransferFrom` via the IP
    /// account.
    /// @dev Does not support batch transfers.
    /// @param ipAccount The IP account to transfer the ERC1155 token from
    /// @param to The recipient of the token
    /// @param tokenContract The address of the ERC1155 token contract
    /// @param tokenId The ID of the token to transfer
    /// @param amount The amount of token to transfer
    function transferERC1155(
        address payable ipAccount,
        address to,
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,uint256,bytes)",
                ipAccount,
                to,
                tokenId,
                amount,
                ""
            )
        );
    }
}
