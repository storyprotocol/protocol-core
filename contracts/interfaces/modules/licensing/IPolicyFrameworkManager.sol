// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title IPolicyFrameworkManager
/// @notice Interface to define a policy framework contract, that will
/// register itself into the LicenseRegistry to format policy into the LicenseRegistry
interface IPolicyFrameworkManager is IERC165 {
    struct VerifyLinkResponse {
        bool isLinkingAllowed;
        bool isRoyaltyRequired;
        address royaltyPolicy;
        uint32 royaltyDerivativeRevShare;
    }

    /// @notice Name to be show in LNFT metadata
    function name() external view returns (string memory);
    /// @notice URL to the off chain legal agreement template text
    function licenseTextUrl() external view returns (string memory);
    /// @notice address of Story Protocol licensing module
    function licensingModule() external view returns (address);

    /// @notice called by the LicenseRegistry uri(uint256) method.
    /// Must return ERC1155 OpenSea standard compliant metadata
    function policyToJson(bytes memory policyData) external view returns (string memory);

    /// @notice Returns the royalty policy address of a policy ID belonging to the PFM
    function getRoyaltyPolicy(uint256 policyId) external view returns (address royaltyPolicy);

    /// @notice Returns the commercial revenue share of a policy ID belonging to the PFM
    function getCommercialRevenueShare(uint256 policyId) external view returns (uint32 commercialRevenueShare);

    /// @notice Returns the minting fee amount of a policy ID belonging to the PFM
    function getMintingFeeAmount(uint256 policyId) external view returns (uint256 mintingFeeAmount);

    /// @notice Returns the minting fee token of a policy ID belonging to the PFM
    function getMintingFeeToken(uint256 policyId) external view returns (address mintingFeeToken);

    /// @notice Returns whether the policy ID belonging to the PFM is commercial or non-commercial
    function isPolicyCommercial(uint256 policyId) external view returns (bool);

    function processInheritedPolicies(
        bytes memory aggregator,
        uint256 policyId,
        bytes memory policy
    ) external view returns (bool changedAgg, bytes memory newAggregator);

    function verifyMint(
        address caller,
        bool policyWasInherited,
        address licensor,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool);

    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (VerifyLinkResponse memory);
}
