// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";

/// @title ILinkParamVerifier
/// @notice LicenseRegistry will call this to verify the linking an IP to its parent
/// with the policy referenced by the license in use.
<<<<<<< HEAD
interface ILinkParamVerifier is IPolicyVerifier {
=======
interface ILinkParamVerifier is IParamVerifier {
>>>>>>> 5b1360b (comments and linting)
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (bool);
}