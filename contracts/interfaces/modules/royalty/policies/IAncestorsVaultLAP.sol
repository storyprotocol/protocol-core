// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRoyaltyPolicyLAP } from "./IRoyaltyPolicyLAP.sol";

/// @title Liquid absolute percentage policy ancestor vault interface
interface IAncestorsVaultLAP {
    /// @notice Event emitted when a claim is made
    /// @param ipId The ipId address
    /// @param claimerIpId The claimer ipId address
    /// @param withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param tokens The ERC20 tokens to withdraw
    event Claimed(address ipId, address claimerIpId, bool withdrawETH, ERC20[] tokens);

    /// @notice Returns the canonical RoyaltyPolicyLAP
    function ROYALTY_POLICY_LAP() external view returns (IRoyaltyPolicyLAP);

    /// @notice Allows an ancestor IP asset to claim their Royalty NFTs and accrued royalties
    /// @param ipId The ipId of the IP asset
    /// @param claimerIpId The ipId of the claimer
    /// @param ancestors The ancestors of the IP
    /// @param ancestorsRoyalties The royalties of the ancestors
    /// @param withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param tokens The ERC20 tokens to withdraw
    function claim(
        address ipId,
        address claimerIpId,
        address[] calldata ancestors,
        uint32[] calldata ancestorsRoyalties,
        bool withdrawETH,
        ERC20[] calldata tokens
    ) external;
}
