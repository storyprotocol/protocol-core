// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

contract MintPaymentVerifier is IParamVerifier, IMintParamVerifier, ERC165 {

    using ShortStrings for *;

    IERC20 public token;
    uint256 public payment;

    string constant NAME = "MintPaymentVerifier";

    constructor(address _token, uint256 _payment) {
        token = IERC20(_token);
        payment = _payment;
    }

    /// @dev Mock verifies the param by decoding it as a bool. If you want the verifier
    /// to return true, pass in abi.encode(true) as the value.
    function verifyMint(
        address caller,
        uint256 policyId,
        bool policyAddedByLinking,
        address licensors,
        address receiver,
        bytes memory data
    ) external view returns (bool) {
        // TODO: return false on approval or transfer failure
        require(token.allowance(caller, address(this)) >= payment, "MintPaymentVerifier: Approval");
        require(token.transferFrom(caller, address(this), payment), "MintPaymentVerifier: Transfer");
        return true;
    }

    function verifyTransfer(address, uint256, bytes memory) external pure returns (bool) {
        return true;
    }

    function verifyLinkParent(address, bytes memory) external pure returns (bool) {
        return true;
    }

    function verifyActivation(address, bytes memory) external pure returns (bool) {
        return true;
    }

    function name() external pure returns (bytes32) {
        return ShortStringOps.stringToBytes32(NAME);
    }

    function nameString() external pure returns (string memory) {
        return NAME;
    }

    function json() external pure returns (string memory) {
        return "";
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external pure returns (bool) {
        return true;
    }

}
