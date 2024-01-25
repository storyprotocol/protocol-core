// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

interface ILinkParentParamVerifier is IParamVerifier {
    function verifyLink(
        address licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata data
    ) external view returns (bool);
}