// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

// TODO: separate core functionality from periphery, UML specific functionality
// TODO: upgradeable
contract PolicyCreator {

    event UMLPolicyCreated(uint256 indexed policyId, UMLPolicy policy);

    struct UMLPolicy {
        bool commercialUse;
        // string[] commLimitedCommercializers;
        bool commWithAttribution;
        uint256 commRevenueShare;
        bool reproWithAttribution;
        bool derivatives;
        bool derivWithApproval;
        bool derivWithReciprocal;
        uint256 derivRevenueShare;
        uint256 derivRevenueCeiling;
        bool transferable;
    }

    ILicenseRegistry public immutable LICENSE_REGISTRY;
    uint256 public immutable FRAMEWORK_ID;
    IParamVerifier  public immutable DERIV_WITH_APPROVAL_PV;

    constructor(
        address licenseRegistry,
        uint256 frameworkId,
        address derivWithApprovalPV
    ) {
        if (licenseRegistry == address(0)) {
            revert Errors.PolicyCreator__ZeroAddressConstructor();
        }
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        FRAMEWORK_ID = frameworkId;
        if (derivWithApprovalPV == address(0)) {
            revert Errors.PolicyCreator__ZeroAddressConstructor();
        }
        DERIV_WITH_APPROVAL_PV = IParamVerifier(derivWithApprovalPV);
    }

    function createPolicy(UMLPolicy calldata policy) external returns (uint256) {
        _verifyPolicy(policy);
        uint256 totalParams = 0;
        mapping(uint256 => IParamVerifier) storage paramVerifiers; // this should be transient
        if (policy.commWithAttribution) {

            totalParams++;
        }
        /*
        if (policy.commRevenueShare > 0) {
            totalParams++;
        }
        if (policy.reproWithAttribution) {
            totalParams++;
        }
        if (policy.derivWithApproval) {
            totalParams++;
        }
        if (policy.derivWithReciprocal) {
            totalParams++;
        }

        bool derivWithApproval;
        bool derivWithReciprocal;
        uint256 derivRevenueShare;
        uint256 derivRevenueCeiling;
        bool transferable;
        
        Licensing.Policy memory pol = Licensing.Policy({
            commercialUse: policy.commercialUse,
            derivatives: policy.derivatives,
        })
       */
    }

    function _verifyPolicy(UMLPolicy calldata policy) internal pure {
        if (!policy.derivatives) {
            if (
                policy.derivWithApproval ||
                policy.derivWithReciprocal ||
                policy.derivRevenueShare > 0 ||
                policy.derivRevenueCeiling > 0
            ) {
                revert Errors.PolicyCreator__IncompatibleDerivatives();
            }
        }
        if (!policy.commercialUse) {
            if (
                policy.derivRevenueShare > 0 ||
                policy.derivRevenueCeiling > 0 ||
                policy.commWithAttribution ||
                policy.commRevenueShare > 0
                // policy.commLimitedCommercializers.length > 0 ||
            ) {
                revert Errors.PolicyCreator__IncompatibleCommercialUse();
            }
        }
    }
}