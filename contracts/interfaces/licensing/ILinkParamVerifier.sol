// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

/// @title ILinkParamVerifier
/// @notice LicenseRegistry will call this to verify the linking an IP to its parent
/// with the policy referenced by the license in use.
interface ILinkParamVerifier is IParamVerifier {
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (bool);
}