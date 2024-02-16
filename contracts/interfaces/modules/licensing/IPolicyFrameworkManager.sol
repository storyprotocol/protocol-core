// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

import { ILicensingModule } from "./ILicensingModule.sol";

/// @title IPolicyFrameworkManager
/// @notice Interface to define a policy framework contract, that will register itself into the LicenseRegistry to 
/// format policy into the LicenseRegistry
interface IPolicyFrameworkManager is IERC165 {
    /// @notice Response struct when verifying a link of an IP asset to a parent IP asset using a license NFT
    /// @param isLinkingAllowed Whether or not the linking is allowed
    /// @param isRoyaltyRequired Whether or not the royalty is required
    /// @param royaltyPolicy The address of the royalty policy, if required. Otherwise, must be zero address.
    /// @param royaltyDerivativeRevShare The derivative revenue share of the royalty policy, if royalty is required. 
    /// Otherwise, must be zero.
    struct VerifyLinkResponse {
        bool isLinkingAllowed;
        bool isRoyaltyRequired;
        address royaltyPolicy;
        uint32 royaltyDerivativeRevShare;
    }

    /// @notice Returns the name to be show in license NFT (LNFT) metadata
    function name() external view returns (string memory);

    /// @notice Returns the URL to the off chain legal agreement template text
    function licenseTextUrl() external view returns (string memory);

    /// @notice called by the LicenseRegistry uri(uint256) method.
    /// @dev Must return ERC1155 OpenSea standard compliant metadata.
    /// @param policyData The encoded licensing policy data to be decoded by the PFM
    /// @return string The OpenSea-compliant metadata URI of the policy
    function policyToJson(bytes memory policyData) external view returns (string memory);

    /// @notice Returns the royalty policy address of a policy ID belonging to the PFM
    /// @param policyId The policy ID to get
    /// @return royaltyPolicy The royalty policy address
    function getRoyaltyPolicy(uint256 policyId) external view returns (address royaltyPolicy);

    /// @notice Returns the commercial revenue share of a policy ID belonging to the PFM
    /// @param policyId The policy ID to get
    /// @return commercialRevenueShare The commercial revenue share of the policy
    function getCommercialRevenueShare(uint256 policyId) external view returns (uint32 commercialRevenueShare);

    /// @notice Returns whether the policyId belonging to the PFM is commercial or non-commercial
    /// @param policyId The policy ID to check
    /// @return isCommercial True if the policy is commercial
    function isPolicyCommercial(uint256 policyId) external view returns (bool);

    /// @notice Verify the compatibility of a policy with the current state of the IP asset, when inheriting from a 
    /// parent IP. The current state of the IP asset, represented as the encoded aggregator bytes, is the combination
    /// of all policies previously attached to the IP asset.
    /// @dev Enforced to be only callable by the LicenseRegistry.
    /// @param aggregator The common state of the policies for the given IP asset
    /// @param policyId The ID of the new policy being inherited
    /// @param policy The encoded policy data of the policyId to inherit
    /// @return changedAgg True if the aggregator was changed
    /// @return newAggregator The new aggregator data, encoded
    function processInheritedPolicies(
        bytes memory aggregator,
        uint256 policyId,
        bytes memory policy
    ) external view returns (bool changedAgg, bytes memory newAggregator);

    /// @notice Verifies the given policy paramters when linking an IP asset with a parent IP asset.
    /// @dev Enforced to be only callable by the LicenseRegistry.
    /// @param licenseId The ID of the license NFT used for linking to parent IP
    /// @param caller The address of the caller
    /// @param ipId The ID of the child IP asset being linked to parent IP
    /// @param parentIpId The ID of the parent IP asset being linked to
    /// @param policyData The encoded licensing policy data to be decoded by the PFM for verification
    /// @return verifyLinkResponse The response of the linking verification
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (VerifyLinkResponse memory);

    /// @notice Verifies the given policy paramters when minting a license NFT from an IP asset.
    /// @dev Enforced to be only callable by the LicenseRegistry.
    /// @param caller The address of the caller
    /// @param policyWasInherited Whether or not the policy was inherited from a parent IP asset
    /// @param licensor The address of the licensor (IP asset with the policy)
    /// @param receiver The address of the receiver to receive the minted license NFT
    /// @param mintAmount The amount of license NFTs to mint
    /// @param policyData The encoded licensing policy data to be decoded by the PFM for verification
    /// @return isMintAllowed True if the verification passed and minting is allowed
    function verifyMint(
        address caller,
        bool policyWasInherited,
        address licensor,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool);
}
