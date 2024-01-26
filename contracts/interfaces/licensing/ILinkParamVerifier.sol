// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

interface ILinkParamVerifier is IParamVerifier {
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata data
    ) external returns (bool);
}