// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IParamVerifier {

    function verifyParam(address caller, bytes memory value) external view returns (bool);
    function json() external view returns (string memory);
}
