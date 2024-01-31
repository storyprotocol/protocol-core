// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Liquid split policy claimer interface
interface IClaimerLS {
    /// @notice Event emitted when a claim is made
    /// @param path The path from the ipId to the claimer
    /// @param claimer The claimer ipId address
    /// @param withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param tokens The ERC20 tokens to withdraw
    event Claimed(address[] path, address claimer, bool withdrawETH, ERC20[] tokens);

    /// @notice Allows an ipId to claim their rnfts and accrued royalties
    /// @param path The path of the ipId
    /// @param claimerIpId The ipId of the claimer
    /// @param withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param tokens The ERC20 tokens to withdraw
    function claim(address[] calldata path, address claimerIpId, bool withdrawETH, ERC20[] calldata tokens) external;
}