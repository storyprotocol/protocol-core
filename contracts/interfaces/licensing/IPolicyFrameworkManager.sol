// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

/// @title IPolicyFrameworkManager
/// @notice Interface to define a licensing framework contract, that will
/// register itself into the LicenseRegistry to format policy into the LicenseRegistry
interface IPolicyFrameworkManager is IParamVerifier {
    function licenseRegistry() external view returns (address);
    function policyToJson(bytes memory policyData) external view returns (string memory);
}