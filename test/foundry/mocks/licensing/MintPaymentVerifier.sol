// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
// contracts
import { BaseParamVerifier } from "contracts/modules/licensing/parameters/BaseParamVerifier.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

contract MintPaymentVerifier is BaseParamVerifier, IMintParamVerifier {
    using ShortStrings for *;

    IERC20 public token;
    uint256 public payment;

    constructor(
        address licenseRegistry,
        address _token,
        uint256 _payment
    ) BaseParamVerifier(licenseRegistry, "MintPaymentVerifier") {
        token = IERC20(_token);
        payment = _payment;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IParamVerifier).interfaceId ||
            interfaceId == type(IMintParamVerifier).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @dev Mock verifies the param by decoding it as a bool. If you want the verifier
    /// to return true, pass in abi.encode(true) as the value.
    function verifyMint(
        address caller,
        uint256 policyId,
        bool policyAddedByLinking,
        address licensors,
        address receiver,
        uint256 mintAmount,
        bytes memory data
    ) external returns (bool) {
        // TODO: return false on approval or transfer failure
        uint256 payment_ = mintAmount * payment;
        require(token.allowance(caller, address(this)) >= payment_, "MintPaymentVerifier: Approval");
        require(token.transferFrom(caller, address(this), payment_), "MintPaymentVerifier: Transfer");
        return true;
    }

    function isCommercial() external pure returns (bool) {
        return false;
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external pure returns (bool) {
        return true;
    }
}
