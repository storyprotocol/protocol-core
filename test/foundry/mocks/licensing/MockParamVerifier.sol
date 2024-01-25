// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

contract MockIParamVerifier is IParamVerifier {
    function verifyMinting(address, uint256, bytes memory value) external pure returns (bool) {
        return abi.decode(value, (bool));
    }

    function verifyLinkParent(address, bytes memory value) external pure returns (bool) {
        return abi.decode(value, (bool));
    }

    function verifyActivation(address, bytes memory value) external pure returns (bool) {
        return abi.decode(value, (bool));
    }

    function verifyTransfer(address, uint256, bytes memory value) external pure returns (bool) {
        return abi.decode(value, (bool));
    }

    function json() external pure returns (string memory) {
        return "";
    }

    function name() external pure override returns (string memory) {
        return "Mock";
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external view override returns (bool) {
        return true;
    }
}
