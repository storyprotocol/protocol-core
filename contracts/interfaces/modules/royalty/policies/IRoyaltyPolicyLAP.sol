// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IRoyaltyPolicy } from "../../../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

/// @title RoyaltyPolicy interface
interface IRoyaltyPolicyLAP is IRoyaltyPolicy {
    struct InitParams {
        address[] targetAncestors; // the expected ancestors of an ipId
        uint32[] targetRoyaltyAmount; // the expected royalties of each of the ancestors for an ipId
        address[] parentAncestors1; // all the ancestors of the first parent
        address[] parentAncestors2; // all the ancestors of the second parent
        uint32[] parentAncestorsRoyalties1; // the royalties of each of the ancestors for the first parent
        uint32[] parentAncestorsRoyalties2; // the royalties of each of the ancestors for the second parent
    }

    /// @notice Event emitted when a policy is initialized
    /// @param ipId The ipId
    /// @param splitClone The split clone address
    /// @param ancestorsVault The ancestors vault address
    /// @param royaltyStack The royalty stack
    /// @param targetAncestors The ip ancestors array
    /// @param targetRoyaltyAmount The ip royalty amount array
    event PolicyInitialized(
        address ipId,
        address splitClone,
        address ancestorsVault,
        uint32 royaltyStack,
        address[] targetAncestors,
        uint32[] targetRoyaltyAmount
    );

    /// @notice Gets the royalty data
    /// @param ipId The ipId
    /// @return isUnlinkable Indicates if the ipId is unlinkable
    ///         splitClone The split clone address
    ///         ancestorsVault The ancestors vault address
    ///         royaltyStack The royalty stack
    ///         ancestorsHash The unique ancestors hash
    function royaltyData(
        address ipId
    )
        external
        view
        returns (
            bool isUnlinkable,
            address splitClone,
            address ancestorsVault,
            uint32 royaltyStack,
            bytes32 ancestorsHash
        );

    /// @notice Gets liquid split main address
    function LIQUID_SPLIT_MAIN() external view returns (address);

    /// @notice Set the ancestors vault implementation address
    /// @param _ancestorsVaultImpl The ancestors vault implementation address
    function setAncestorsVaultImplementation(address _ancestorsVaultImpl) external;

    /// @notice Distributes funds internally so that accounts holding the royalty nfts at distribution moment can
    /// claim afterwards
    /// @param _ipId The ipId
    /// @param _token The token to distribute
    /// @param _accounts The accounts to distribute to
    /// @param _distributorAddress The distributor address
    function distributeIpPoolFunds(
        address _ipId,
        address _token,
        address[] calldata _accounts,
        address _distributorAddress
    ) external;

    /// @notice Claims the available royalties for a given address
    /// @param _account The account to claim for
    /// @param _withdrawETH The amount of ETH to withdraw
    /// @param _tokens The tokens to withdraw
    function claimFromIpPool(address _account, uint256 _withdrawETH, ERC20[] calldata _tokens) external;

    /// @notice Claims the available royalties for a given address that holds all the royalty nfts of an ipId
    /// @param _ipId The ipId
    /// @param _withdrawETH The amount of ETH to withdraw
    /// @param _token The token to withdraw
    function claimFromIpPoolAsTotalRnftOwner(address _ipId, uint256 _withdrawETH, address _token) external;

    /// @notice Claims all available royalty nfts and accrued royalties for an ancestor of a given ipId
    /// @param _ipId The ipId
    /// @param _claimerIpId The claimer ipId
    /// @param _ancestors The ancestors of the IP
    /// @param _ancestorsRoyalties The royalties of the ancestors
    /// @param _withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param _tokens The ERC20 tokens to withdraw
    function claimFromAncestorsVault(
        address _ipId,
        address _claimerIpId,
        address[] calldata _ancestors,
        uint32[] calldata _ancestorsRoyalties,
        bool _withdrawETH,
        ERC20[] calldata _tokens
    ) external;
}
