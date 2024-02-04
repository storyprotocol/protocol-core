// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";
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

    function verifyTransfer(
        uint256 licenseId,
        address from,
        address to,
        uint256 amount,
        bytes memory policyData
    ) external returns (bool);
}
