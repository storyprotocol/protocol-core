// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRoyaltyPolicy } from "../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicyLAP is IRoyaltyPolicy {
    /// @notice Event emitted when a policy is initialized
    /// @param ipId The ipId
    /// @param splitClone The split clone address
    /// @param claimer The claimer address
    /// @param royaltyStack The royalty stack
    /// @param targetAncestors The ip ancestors array
    /// @param targetRoyaltyAmount The ip royalty amount array
    event PolicyInitialized(address ipId, address splitClone, address claimer, uint32 royaltyStack, address[] targetAncestors, uint32[] targetRoyaltyAmount);

    /// @notice Gets the royalty data
    /// @param ipId The ipId
    /// @return isUnlinkable Indicates if the ipId is unlinkable
    ///         splitClone The split clone address
    ///         claimer The claimer address
    ///         royaltyStack The royalty stack
    ///         ancestorsHash The unique ancestors hash
    function royaltyData(
        address ipId
    ) external view returns (bool isUnlinkable, address splitClone, address claimer, uint32 royaltyStack, bytes32 ancestorsHash);

    /// @notice Distributes funds to the accounts in the LiquidSplitClone contract
    /// @param ipId The ipId
    /// @param token The token to distribute
    /// @param accounts The accounts to distribute to
    /// @param distributorAddress The distributor address
    function distributeIpPoolFunds(
        address ipId,
        address token,
        address[] calldata accounts,
        address distributorAddress
    ) external;

    /// @notice Claims the available royalties for a given account
    /// @param account The account to claim for
    /// @param withdrawETH The amount of ETH to withdraw
    /// @param tokens The tokens to withdraw
    function claimFromIpPool(address account, uint256 withdrawETH, ERC20[] calldata tokens) external;

    /// @notice Gets liquid split main address
    function LIQUID_SPLIT_MAIN() external view returns (address);
}
