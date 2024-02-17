// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title IPolicyFrameworkManager
/// @notice Interface to define a policy framework contract, that will
/// register itself into the LicenseRegistry to format policy into the LicenseRegistry
interface IPolicyFrameworkManager is IERC165 {
    /// @notice Name to be show in LNFT metadata
    function name() external view returns (string memory);
    /// @notice URL to the off chain legal agreement template text
    function licenseTextUrl() external view returns (string memory);
    /// @notice address of Story Protocol licensing module
    function licensingModule() external view returns (address);

    /// @notice called by the LicenseRegistry uri(uint256) method.
    /// Must return ERC1155 OpenSea standard compliant metadata
    function policyToJson(bytes memory policyData) external view returns (string memory);

    /// Called by licenseRegistry to verify compatibility when inheriting from a parent IP
    /// The objective is to verify compatibility of multiple policies.
    /// @dev The assumption in this method is that we can add parents later on, hence the need
    /// for an aggregator, if not we will do this when linking to parents directly with an
    /// array of policies.
    /// @param aggregator common state of the policies for the IP
    /// @param policyId the ID of the policy being inherited
    /// @param policy the policy to inherit
    /// @return changedAgg  true if the aggregator was changed
    /// @return newAggregator the new aggregator
    function processInheritedPolicies(
        bytes memory aggregator,
        uint256 policyId,
        bytes memory policy
    ) external view returns (bool changedAgg, bytes memory newAggregator);

    /// Called by licenseRegistry to verify policy parameters for minting a license
    /// @param caller the address executing the mint
    /// @param policyWasInherited true if the policy was inherited (licensorIpId is not original IP owner)
    /// @param receiver the address receiving the license
    /// @param licensorIpId the IP id of the licensor
    /// @param mintAmount the amount of licenses to mint
    /// @param policyData the encoded framework policy data to verify
    function verifyMint(
        address caller,
        bool policyWasInherited,
        address licensorIpId,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool);

    /// Called by licenseRegistry to verify policy parameters for linking a child IP to a parent IP (licensor)
    /// by burning a license.
    /// @param licenseId the license id to burn
    /// @param caller the address executing the link
    /// @param ipId the IP id of the IP being linked
    /// @param parentIpId the IP id of the parent IP
    /// @param policyData the encoded framework policy data to verify
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (bool);
}
