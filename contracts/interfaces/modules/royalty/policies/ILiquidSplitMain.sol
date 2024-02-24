// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title LiquidSplitMain interface
interface ILiquidSplitMain {
    /// @notice Allows an account to withdraw their accrued and distributed pending amount
    /// @param account The account to withdraw from
    /// @param withdrawETH The amount of ETH to withdraw
    /// @param tokens The tokens to withdraw
    function withdraw(address account, uint256 withdrawETH, ERC20[] calldata tokens) external;

    /// @notice Gets the ETH balance of an account
    /// @param account The account to get the ETH balance of
    /// @return balance The ETH balance of the account
    function getETHBalance(address account) external view returns (uint256);

    /// @notice Gets the ERC20 balance of an account
    /// @param account The account to get the ERC20 balance of
    /// @param token The token to get the balance of
    /// @return balance The ERC20 balance of the account
    function getERC20Balance(address account, ERC20 token) external view returns (uint256);
}
