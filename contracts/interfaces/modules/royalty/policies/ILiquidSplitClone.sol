// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title LiquidSplitClone interface
interface ILiquidSplitClone {
    /// @notice Distributes funds to the accounts in the LiquidSplitClone contract
    /// @param token The token to distribute
    /// @param accounts The accounts to distribute to
    /// @param distributorAddress The distributor address
    function distributeFunds(address token, address[] calldata accounts, address distributorAddress) external;

    /// @notice Transfers rnft tokens
    /// @param from The address to transfer from
    /// @param to The address to transfer to
    /// @param id The token id
    /// @param amount The amount to transfer
    /// @param data Custom data
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /// @notice Returns the balance of the account
    /// @param account The account to check
    /// @param id The token id
    /// @return balance The balance of the account
    function balanceOf(address account, uint256 id) external view returns (uint256);
}
