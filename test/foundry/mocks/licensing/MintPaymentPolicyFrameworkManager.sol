// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// contracts
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/modules/licensing/IPolicyFrameworkManager.sol";

struct MintPaymentPolicy {
    bool mustBeTrue;
}

contract MintPaymentPolicyFrameworkManager is BasePolicyFrameworkManager {
    IERC20 public token;
    uint256 public payment;

    event MintPaymentPolicyAdded(uint256 indexed policyId, MintPaymentPolicy policy);

    constructor(
        address licensingModule,
        string memory name,
        string memory licenseUrl,
        address _token,
        uint256 _payment
    ) BasePolicyFrameworkManager(licensingModule, name, licenseUrl) {
        token = IERC20(_token);
        payment = _payment;
    }

    function registerPolicy(MintPaymentPolicy calldata mmpol) external returns (uint256 policyId) {
        emit MintPaymentPolicyAdded(policyId, mmpol);
        return LICENSING_MODULE.registerPolicy(abi.encode(mmpol));
    }

    function processInheritedPolicies(
        bytes memory, // aggregator
        uint256, // policyId
        bytes memory // policy
    ) external pure override returns (bool changedAgg, bytes memory newAggregator) {
        return (false, newAggregator);
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

    function verifyLink(
        uint256, // licenseId
        address, // caller
        address, // ipId
        address, // parentIpId
        bytes calldata // policyData
    ) external pure returns (IPolicyFrameworkManager.VerifyLinkResponse memory) {
        return IPolicyFrameworkManager.VerifyLinkResponse({
            isLinkingAllowed: true,
            isRoyaltyRequired: false,
            royaltyPolicy: address(0),
            royaltyDerivativeRevShare: 0
        });
    }

    function verifyTransfer(
        uint256, // licenseId
        address, // from
        address, // to
        uint256, // amount
        bytes memory // policyData
    ) external returns (bool) {
        return true;
    }


    function policyToJson(bytes memory policyData) public pure returns (string memory) {
        return "MintPaymentPolicyFrameworkManager";
    }
}
