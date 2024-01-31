// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title LiquidSplitClone interface
interface ILiquidSplitClone {
    /// @notice Distributes funds to the accounts in the LiquidSplitClone contract
    /// @param token The token to distribute
    /// @param accounts The accounts to distribute to
    /// @param distributorAddress The distributor address
    function distributeFunds(address token, address[] calldata accounts, address distributorAddress) external;
}
