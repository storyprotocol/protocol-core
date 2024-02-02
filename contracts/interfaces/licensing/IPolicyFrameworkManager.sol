// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";
import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";

/// @title IPolicyFrameworkManager
/// @notice Interface to define a policy framework contract, that will
/// register itself into the LicenseRegistry to format policy into the LicenseRegistry
interface IPolicyFrameworkManager is IPolicyVerifier {
    // TODO: move here the interfaces for verification and sunset IPolicyVerifier

    /// @notice Name to be show in LNFT metadata
    function name() external view returns (string memory);
    /// @notice URL to the off chain legal agreement template text
    function licenseTextUrl() external view returns (string memory);
    /// @notice address of Story Protocol license registry
    function licenseRegistry() external view returns (address);

    /// @notice called by the LicenseRegistry uri(uint256) method.
    /// Must return ERC1155 OpenSea standard compliant metadata
    function policyToJson(bytes memory policyData) external view returns (string memory);

    function processInheritedPolicy(
        bytes memory ipRights,
        bytes memory policy
    ) external view returns (bool changedRights, bytes memory newRights);
}
