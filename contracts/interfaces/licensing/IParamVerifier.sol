// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";

interface IParamVerifier is IERC165 {
    function name() external view returns (bytes32);

    function nameString() external view returns (string memory);

    function json() external view returns (string memory);

    function allowsOtherPolicyOnSameIp(bytes memory data) external view returns (bool);
}
