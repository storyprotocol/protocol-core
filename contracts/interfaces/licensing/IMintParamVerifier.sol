// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;
import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";

/// @title IMintParamVerifier
/// @notice LicenseRegistry will call this to verify the minting parameters are compliant
/// with the policy associated with the license to mint.
interface IMintParamVerifier is IPolicyVerifier {
    function verifyMint(
        address caller,
        bool policyWasInherited,
        address licensor,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool);
}