// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

interface ITransferParamVerifier is IParamVerifier {
    function verifyTransfer(
        uint256 licenseId,
        address from,
        address to,
        uint256 amount,
        bytes memory data
    ) external view returns (bool);
}