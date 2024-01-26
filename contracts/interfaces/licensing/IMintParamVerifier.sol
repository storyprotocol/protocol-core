// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

interface IMintParamVerifier is IParamVerifier {
    function verifyMint(
        address caller,
        uint256 policyId,
        bool policyAddedByLinking,
        address licensors,
        address receiver,
        bytes memory data
    ) external returns (bool);
}

