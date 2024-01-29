// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// contracts
import { BaseLicensingModule } from "contracts/modules/licensing/BaseLicensingModule.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

contract MintPaymentLicensingModule is BaseLicensingModule, IMintParamVerifier {

    IERC20 public token;
    uint256 public payment;

    constructor(
        address licenseRegistry,
        string memory licenseUrl,
        address _token,
        uint256 _payment
    ) BaseLicensingModule(licenseRegistry, licenseUrl) {
        token = IERC20(_token);
        payment = _payment;
    }

    function supportsInterface(bytes4 interfaceId)
        public view virtual
        override(IERC165, BaseLicensingModule)
        returns (bool) {
        return
            interfaceId == type(IParamVerifier).interfaceId ||
            interfaceId == type(IMintParamVerifier).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @dev Mock verifies the param by decoding it as a bool. If you want the verifier
    /// to return true, pass in abi.encode(true) as the value.
    function verifyMint(
        address caller,
        bool policyAddedByLinking,
        address licensors,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool) {
        // TODO: return false on approval or transfer failure
        uint256 payment_ = mintAmount * payment;
        require(token.allowance(caller, address(this)) >= payment_, "MintPaymentVerifier: Approval");
        require(token.transferFrom(caller, address(this), payment_), "MintPaymentVerifier: Transfer");
        return true;
    }

    function policyToJson(bytes memory policyData) public view returns (string memory) {
        return "MintPaymentLicensingModule";
    }

}
