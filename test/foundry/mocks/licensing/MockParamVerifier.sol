// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

contract MockIParamVerifier is IParamVerifier, IMintParamVerifier, ILinkParamVerifier, ITransferParamVerifier {
    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return
            interfaceId == type(IParamVerifier).interfaceId ||
            interfaceId == type(IMintParamVerifier).interfaceId ||
            interfaceId == type(ILinkParamVerifier).interfaceId ||
            interfaceId == type(ITransferParamVerifier).interfaceId;
    }

    function json() external pure returns (string memory) {
        return "";
    }

    function nameString() external pure override returns (string memory) {
        return "Mock";
    }

    function name() external pure override returns (bytes32) {
        return ShortStringOps.stringToBytes32("Mock");
    }

    function isCommercial() external pure override returns (bool) {
        return false;
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external view override returns (bool) {
        return true;
    }

    function verifyMint(address, uint256, bool, address, address, uint256, bytes memory data) external view returns (bool) {
        return abi.decode(data, (bool));
    }

    function verifyLink(uint256, address, address, address, bytes calldata data) external view override returns (bool) {
        return abi.decode(data, (bool));
    }

    function verifyTransfer(
        uint256,
        address,
        address,
        uint256,
        bytes memory data
    ) external view override returns (bool) {
        return abi.decode(data, (bool));
    }
}
