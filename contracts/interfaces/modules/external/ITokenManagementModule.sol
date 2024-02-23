// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IModule } from "../base/IModule.sol";

/// @title Token Management Module
/// @notice Module for transferring ERC20, ERC721, and ERC1155 tokens for IP Accounts.
/// @dev SECURITY RISK: An IPAccount can delegate to a frontend contract (not a registered module) to transfer tokens
/// on behalf of the IPAccount via the Token Management Module. This frontend contract can transfer any tokens that are
/// approved by the IPAccount for the Token Management Module. In other words, there's no mechanism for this module to
/// granularly control which token a caller (approved contract in this case) can transfer.
interface ITokenManagementModule is IModule {
    /// @notice Transfers ERC20 token from the IP account to the specified recipient.
    /// @dev When calling this function, the caller must have the permission to call `transfer` via the IP account.
    /// @dev Does not support transfer of multiple tokens at once.
    /// @param ipAccount The IP account to transfer the ERC20 token from
    /// @param to The recipient of the token
    /// @param tokenContract The address of the ERC20 token contract
    /// @param amount The amount of token to transfer
    function transferERC20(address payable ipAccount, address to, address tokenContract, uint256 amount) external;

    /// @notice Transfers ERC721 token from the IP account to the specified recipient.
    /// @dev When calling this function, the caller must have the permission to call `transferFrom` via the IP account.
    /// @dev Does not support batch transfers.
    /// @param ipAccount The IP account to transfer the ERC721 token from
    /// @param to The recipient of the token
    /// @param tokenContract The address of the ERC721 token contract
    /// @param tokenId The ID of the token to transfer
    function transferERC721(address payable ipAccount, address to, address tokenContract, uint256 tokenId) external;

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
    ) external;
}
