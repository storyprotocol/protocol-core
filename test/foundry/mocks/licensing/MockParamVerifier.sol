// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

contract MockIParamVerifier is IParamVerifier {

    function verifyParam(address, bytes memory value) external pure returns (bool) {
        return abi.decode(value, (bool));
    }

    function json() external pure returns (string memory) {
        return "";
    }
}
