// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRoyaltyPolicyLS } from "./IRoyaltyPolicyLS.sol";
import { ILicensingModule } from "../../licensing/ILicensingModule.sol";

/// @title Liquid split policy claimer interface
interface ILSClaimer {
    /// @notice Event emitted when a claim is made.
    /// @param path The path from the ipId to the claimer
    /// @param claimer The claimer ipId address
    /// @param withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param tokens The ERC20 tokens to withdraw
    event Claimed(address[] path, address claimer, bool withdrawETH, ERC20[] tokens);

    /// @notice Returns the licensing module.
    function LICENSING_MODULE() external view returns (ILicensingModule);

    /// @notice Returns the royalty policy.
    function ROYALTY_POLICY_LS() external view returns (IRoyaltyPolicyLS);

    /// @notice Returns the ID of the IP asset with which this LSClaimer is associated.
    function IP_ID() external view returns (address);

    /// @notice Returns if the path between an ancestor/parent IP and a child IP has been claimed.
    /// @param pathHash The hash of the path from an ancestor IP to a child IP
    /// @return isClaimed True if the path has been claimed
    function claimedPaths(bytes32 pathHash) external view returns (bool isClaimed);

    /// @notice Allows an ancestor/parent IP asset to claim its Royalty NFTs (RNFTs) and any accrued royalties.
    /// @param path The path from an ancestor IP to a child IP
    /// @param claimerIpId The ID of the claimer's IP asset
    /// @param withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param tokens The ERC20 tokens to withdraw
    function claim(address[] calldata path, address claimerIpId, bool withdrawETH, ERC20[] calldata tokens) external;
}
