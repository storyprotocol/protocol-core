// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

/// @title ITransferParamVerifier
/// @notice LicenseRegistry will call this to verify the transfer parameters are compliant
/// with the policy
interface ITransferParamVerifier is IParamVerifier {
    function verifyTransfer(
        uint256 licenseId,
        address from,
        address to,
        uint256 amount,
        bytes memory policyData
    ) external returns (bool);
}