// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

/// @title IPolicyFrameworkManager
/// @notice Interface to define a policy framework contract, that will register itself into the LicenseRegistry to
/// format policy into the LicenseRegistry
interface IPolicyFrameworkManager is IERC165 {
    /// @notice Name to be show in LNFT metadata
    function name() external view returns (string memory);

    /// @notice Returns the URL to the off chain legal agreement template text
    function licenseTextUrl() external view returns (string memory);

    /// @notice Returns the stringified JSON policy data for the LicenseRegistry.uri(uint256) method.
    /// @dev Must return ERC1155 OpenSea standard compliant metadata.
    /// @param policyData The encoded licensing policy data to be decoded by the PFM
    /// @return jsonString The OpenSea-compliant metadata URI of the policy
    function policyToJson(bytes memory policyData) external view returns (string memory);

    /// @notice Verify compatibility of one or more policies when inheriting them from one or more parent IPs.
    /// @dev Enforced to be only callable by LicenseRegistry
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

    /// @notice Verify policy parameters for minting a license.
    /// @dev Enforced to be only callable by LicenseRegistry
    /// @param licensee the address that holds the license and is executing the mint
    /// @param mintingFromADerivative true if we verify minting a license from a derivative IP ID
    /// @param receiver the address receiving the license
    /// @param licensorIpId the IP id of the licensor
    /// @param mintAmount the amount of licenses to mint
    /// @param policyData the encoded framework policy data to verify
    /// @return verified True if the link is verified
    function verifyMint(
        address licensee,
        bool mintingFromADerivative,
        address licensorIpId,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool);

    /// @notice Verify policy parameters for linking a child IP to a parent IP (licensor) by burning a license NFT.
    /// @dev Enforced to be only callable by LicenseRegistry
    /// @param licenseId the license id to burn
    /// @param licensee the address that holds the license and is executing the link
    /// @param ipId the IP id of the IP being linked
    /// @param parentIpId the IP id of the parent IP
    /// @param policyData the encoded framework policy data to verify
    /// @return verified True if the link is verified
    function verifyLink(
        uint256 licenseId,
        address licensee,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (bool);
}
