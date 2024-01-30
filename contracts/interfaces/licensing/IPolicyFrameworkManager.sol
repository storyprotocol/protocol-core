// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";
import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";

/// @title IPolicyFrameworkManager
/// @notice Interface to define a policy framework contract, that will
/// register itself into the LicenseRegistry to format policy into the LicenseRegistry
interface IPolicyFrameworkManager is IPolicyVerifier {
    function licenseRegistry() external view returns (address);
    function policyToJson(bytes memory policyData) external view returns (string memory);
}