// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

interface IParamVerifier {
    function name() external pure returns (string memory);
    function json() external pure returns (string memory);
    function allowsOtherPolicyOnSameIp(bytes memory data) external view returns (bool);
}
