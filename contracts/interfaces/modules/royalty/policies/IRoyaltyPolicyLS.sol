// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRoyaltyPolicy } from "../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicyLS is IRoyaltyPolicy {
    /// @notice Liquid Split Royalty Data
    /// @param splitClone The address of the liquid split clone contract for a given IP asset
    /// @param claimer The address of the claimer contract for a given IP asset
    /// @param royaltyStack The royalty stack for a given IP asset is the sum of the minRoyalty of all its ancestors.
    /// Number between 0 and 1000; the smallest increment of 10 represents 1%.
    /// @param minRoyalty The minimum royalty the IP asset will receive from its children and grandchildren
    /// Number between 0 and 1000; the smallest increment of 10 represents 1%.
    struct LSRoyaltyData {
        address splitClone;
        address claimer;
        uint32 royaltyStack;
        uint32 minRoyalty;
    }

    /// @notice Percentage scale - 1000 rnfts represents 100%.
    function TOTAL_RNFT_SUPPLY() external view returns (uint32);

    /// @notice Returns the royalty module address
    function ROYALTY_MODULE() external view returns (address);

    /// @notice Returns the licensing module address
    function LICENSING_MODULE() external view returns (address);

    /// @notice Returns the liquid split factory address
    function LIQUID_SPLIT_FACTORY() external view returns (address);

    /// @notice Returns the liquid split main address
    function LIQUID_SPLIT_MAIN() external view returns (address);

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ID of the IP asset
    /// @return splitClone The split clone address
    /// @return claimer The claimer address
    /// @return royaltyStack The royalty stack
    /// @return minRoyalty The min royalty
    function royaltyData(
        address ipId
    ) external view returns (address splitClone, address claimer, uint32 royaltyStack, uint32 minRoyalty);

    /// @notice Initializes the royalty policy for the given IP asset
    /// @dev Enforced to be only callable by the royalty module
    /// @param ipId The ID of the IP asset
    /// @param parentIpIds List of parent IP asset IDs
    /// @param data The encoded data that will be used by the royalty policy
    function initPolicy(address ipId, address[] calldata parentIpIds, bytes calldata data) external;

    /// @notice Transfers royalty payment according to an IP asset's royalty policy data. Triggered on royalty payment
    /// from the royalty module.
    /// @dev Enforced to be only callable by the royalty module
    /// @param caller The caller to pay the royalty
    /// @param ipId The ID of the IP asset to find the royalty policy data
    /// @param token The ERC20 token to pay
    /// @param amount The token amount to pay to the splitClone defined in the royalty policy data of ipId
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external;

    /// @notice Distributes funds to the accounts in the LiquidSplitClone contract
    /// @param ipId The ID of the IP asset
    /// @param token The ERC20 token to distribute
    /// @param accounts The accounts to distribute to
    /// @param distributorAddress The distributor address
    function distributeFunds(
        address ipId,
        address token,
        address[] calldata accounts,
        address distributorAddress
    ) external;

    /// @notice Claims the available royalties for a given IP account
    /// @param account The IP account to claim for
    /// @param withdrawETH The amount of ETH to withdraw
    /// @param tokens The tokens to withdraw
    function claimRoyalties(address account, uint256 withdrawETH, ERC20[] calldata tokens) external;
}
