// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

/// @title IMintParamVerifier
/// @notice LicenseRegistry will call this to verify the minting parameters are compliant
/// with the policy associated with the license to mint.
interface IMintParamVerifier is IParamVerifier {
    function verifyMint(
        address caller,
        bool policyWasInherited,
        address licensors,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool);
}