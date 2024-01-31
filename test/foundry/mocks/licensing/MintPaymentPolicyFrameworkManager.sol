// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// contracts
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

struct MintPaymentPolicy {
    bool mustBeTrue;
}

contract MintPaymentPolicyFrameworkManager is BasePolicyFrameworkManager, IMintParamVerifier {
    IERC20 public token;
    uint256 public payment;

    event MintPaymentPolicyAdded(uint256 indexed policyId, MintPaymentPolicy policy);

    constructor(
        address licenseRegistry,
        string memory name,
        string memory licenseUrl,
        address _token,
        uint256 _payment
    ) BasePolicyFrameworkManager(licenseRegistry, name, licenseUrl) {
        token = IERC20(_token);
        payment = _payment;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, BasePolicyFrameworkManager) returns (bool) {
        // support only mint param verifier
        return
            interfaceId == type(IPolicyVerifier).interfaceId ||
            interfaceId == type(IMintParamVerifier).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function registerPolicy(MintPaymentPolicy calldata mmpol) external returns (uint256 policyId) {
        require(mmpol.mustBeTrue, "MintPaymentPolicyFrameworkManager: mustBeTrue");
        emit MintPaymentPolicyAdded(policyId, mmpol);
        return LICENSE_REGISTRY.registerPolicy(abi.encode(mmpol));
    }

    /// @dev Mock verifies the param by decoding it as a bool. If you want the verifier
    /// to return true, pass in abi.encode(true) as the value.
    function verifyMint(
        address caller,
        bool, // policyWasInherited
        address, // licensors
        address, // receiver
        uint256 mintAmount,
        bytes memory policyData
    ) external returns (bool) {
        // TODO: return false on approval or transfer failure
        uint256 payment_ = mintAmount * payment;
        require(token.allowance(caller, address(this)) >= payment_, "MintPaymentVerifier: Approval");
        require(token.transferFrom(caller, address(this), payment_), "MintPaymentVerifier: Transfer");
        MintPaymentPolicy memory mmpol = abi.decode(policyData, (MintPaymentPolicy));
        return mmpol.mustBeTrue;
    }

    function policyToJson(bytes memory policyData) public view returns (string memory) {
        return "MintPaymentPolicyFrameworkManager";
    }
}
