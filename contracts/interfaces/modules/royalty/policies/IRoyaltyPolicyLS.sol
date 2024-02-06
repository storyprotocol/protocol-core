// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRoyaltyPolicy } from "../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicyLS is IRoyaltyPolicy {
    /// @notice Gets the royalty data
    /// @param ipId The ipId
    /// @return splitClone The split clone address
    ///         claimer The claimer address
    ///         royaltyStack The royalty stack
    ///         minRoyalty The min royalty
    function royaltyData(address ipId) external view returns (address splitClone, address claimer, uint32 royaltyStack, uint32 minRoyalty);

    /// @notice Distributes funds to the accounts in the LiquidSplitClone contract
    /// @param ipId The ipId
    /// @param token The token to distribute
    /// @param accounts The accounts to distribute to
    /// @param distributorAddress The distributor address
    function distributeFunds(
        address ipId,
        address token,
        address[] calldata accounts,
        address distributorAddress
    ) external;

    /// @notice Claims the available royalties for a given account
    /// @param account The account to claim for
    /// @param withdrawETH The amount of ETH to withdraw
    /// @param tokens The tokens to withdraw
    function claimRoyalties(address account, uint256 withdrawETH, ERC20[] calldata tokens) external;

    /// @notice Gets liquid split main address
    function LIQUID_SPLIT_MAIN() external view returns (address);
}
