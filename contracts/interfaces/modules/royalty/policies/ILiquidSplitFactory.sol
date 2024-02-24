// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

/// @title LiquidSplitFactory interface
interface ILiquidSplitFactory {
    /// @notice Creates a new LiquidSplitClone contract
    /// @param accounts The accounts to initialize the LiquidSplitClone contract with
    /// @param initAllocations The initial allocations
    /// @param _distributorFee The distributor fee
    /// @param owner The owner of the LiquidSplitClone contract
    /// @return address The address of the new LiquidSplitClone contract
    function createLiquidSplitClone(
        address[] calldata accounts,
        uint32[] calldata initAllocations,
        uint32 _distributorFee,
        address owner
    ) external returns (address);
}
