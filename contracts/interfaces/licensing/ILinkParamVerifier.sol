// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";

/// @title ILinkParamVerifier
/// @notice LicenseRegistry will call this to verify the linking an IP to its parent
/// with the policy referenced by the license in use.
interface ILinkParamVerifier is IPolicyVerifier {
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (bool);
}