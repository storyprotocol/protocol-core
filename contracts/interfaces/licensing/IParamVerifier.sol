// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IParamVerifier {
    function verifyMinting(address caller, uint256 amount, bytes memory data) external returns (bool);
    function verifyTransfer(address caller, uint256 amount, bytes memory data) external returns (bool);
    function verifyLinkParent(address caller, bytes memory data) external returns (bool);
    function json() external view returns (string memory);
}
