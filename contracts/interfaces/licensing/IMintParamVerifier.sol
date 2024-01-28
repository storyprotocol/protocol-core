// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

interface IMintParamVerifier is IParamVerifier {
    function verifyMint(
        address caller,
        bool policyAddedByLinking,
        bytes memory policyData,
        address licensors,
        address receiver,
        uint256 mintAmount,
    ) external returns (bool);
}

