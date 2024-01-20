// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

contract MockIParamVerifier is IParamVerifier {
    function verifyMintingParam(address, uint256, bytes memory value) external pure returns (bool) {
        return abi.decode(value, (bool));
    }

    function verifyLinkParentParam(address, bytes memory value) external pure returns (bool) {
        return abi.decode(value, (bool));
    }

    function verifyActivationParam(address, bytes memory value) external pure returns (bool) {
        return abi.decode(value, (bool));
    }

    function json() external pure returns (string memory) {
        return "";
    }
}
