// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title LiquidSplitMain interface
interface ILiquidSplitMain {
    /// @notice Allows an account to withdraw their accrued and distributed pending amount
    /// @param account The account to withdraw from
    /// @param withdrawETH The amount of ETH to withdraw
    /// @param tokens The tokens to withdraw
    function withdraw(address account, uint256 withdrawETH, ERC20[] calldata tokens) external;
}
