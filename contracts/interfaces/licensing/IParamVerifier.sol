// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

interface IParamVerifier {
    function name() external view returns (string memory);
    function json() external view returns (string memory);
    function allowsOtherPolicyOnSameIp(bytes memory data) external view returns (bool);
}
