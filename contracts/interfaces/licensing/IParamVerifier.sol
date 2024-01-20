// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IParamVerifier {
    function verifyMintingParam(address caller, uint256 mintAmount, bytes memory data) external returns (bool);
    function verifyLinkParentParam(address caller, bytes memory data) external returns (bool);
    function verifyActivationParam(address caller, bytes memory data) external returns (bool);
    function json() external view returns (string memory);
}
