// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";

/// @title ITransferParamVerifier
/// @notice LicenseRegistry will call this to verify the transfer parameters are compliant
/// with the policy
interface ITransferParamVerifier is IPolicyVerifier {
    function verifyTransfer(
        uint256 licenseId,
        address from,
        address to,
        uint256 amount,
        bytes memory policyData
    ) external returns (bool);
}
