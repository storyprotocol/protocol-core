// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

contract MintPaymentVerifier is IParamVerifier {
    IERC20 public token;
    uint256 public payment;

    constructor(address _token, uint256 _payment) {
        token = IERC20(_token);
        payment = _payment;
    }

    /// @dev Mock verifies the param by decoding it as a bool. If you want the verifier
    /// to return true, pass in abi.encode(true) as the value.
    function verifyMinting(address caller, uint256 mintAmount, bytes memory) external returns (bool) {
        // TODO: return false on approval or transfer failure
        require(token.allowance(caller, address(this)) >= payment * mintAmount, "MintPaymentVerifier: Approval");
        require(token.transferFrom(caller, address(this), payment * mintAmount), "MintPaymentVerifier: Transfer");
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

    function name() external pure returns (string memory) {
        return "MintPaymentVerifier";
    }

    function json() external pure returns (string memory) {
        return "";
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external pure returns (bool) {
        return true;
    }

}
