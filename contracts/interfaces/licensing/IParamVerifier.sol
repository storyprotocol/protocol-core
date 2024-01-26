// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface IParamVerifier is IERC165 {

    function name() external pure returns (bytes32);
    function nameString() external pure returns (string memory);
    function json() external pure returns (string memory);
    function allowsOtherPolicyOnSameIp(bytes memory data) external view returns (bool);
}
