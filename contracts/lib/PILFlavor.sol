// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { RegisterPILPolicyParams, PILPolicy } from "../interfaces/modules/licensing/IPILPolicyFrameworkManager.sol";
import { ILicensingModule } from "../interfaces/modules/licensing/ILicensingModule.sol";
import { Licensing } from "./Licensing.sol";

/// @title PILFlavors Library
/// @notice Provides a set of predefined PILPolicy configurations for different licensing scenarios
library PILFlavors {
    bytes public constant EMPTY_BYTES = "";

    function defaultPolicy() internal returns (RegisterPILPolicyParams memory) {
        return
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: address(0),
                mintingFee: 0,
                mintingFeeToken: address(0),
                policy: PILPolicy({
                    attribution: false,
                    commercialUse: false,
                    commercialAttribution: false,
                    commercializerChecker: address(0),
                    commercializerCheckerData: EMPTY_BYTES,
                    commercialRevShare: 0,
                    derivativesAllowed: false,
                    derivativesAttribution: false,
                    derivativesApproval: false,
                    derivativesReciprocal: false,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            });
    }

    function getDefaultPolicyId(ILicensingModule module, address pilFramework) internal pure returns (uint256) {
        Licensing.Policy memory policy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: pilFramework,
            frameworkData: abi.encode(
                PILPolicy({
                    attribution: false,
                    commercialUse: false,
                    commercialAttribution: false,
                    commercializerChecker: address(0),
                    commercializerCheckerData: EMPTY_BYTES,
                    commercialRevShare: 0,
                    derivativesAllowed: false,
                    derivativesAttribution: false,
                    derivativesApproval: false,
                    derivativesReciprocal: false,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            ),
            royaltyPolicy: address(0),
            royaltyData: abi.encode(uint256(0)),
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
        return module.getPolicyId(policy);
    }

    function nonCommercialSocialRemixing() internal returns (RegisterPILPolicyParams memory) {
        return
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: address(0),
                mintingFee: 0,
                mintingFeeToken: address(0),
                policy: PILPolicy({
                    attribution: true,
                    commercialUse: false,
                    commercialAttribution: false,
                    commercializerChecker: address(0),
                    commercializerCheckerData: EMPTY_BYTES,
                    commercialRevShare: 0,
                    derivativesAllowed: true,
                    derivativesAttribution: true,
                    derivativesApproval: false,
                    derivativesReciprocal: true,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            });
    }

    function getNonCommercialSocialRemixingId(
        ILicensingModule module,
        address pilFramework
    ) internal pure returns (uint256) {
        Licensing.Policy memory policy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: pilFramework,
            frameworkData: abi.encode(
                PILPolicy({
                    attribution: true,
                    commercialUse: false,
                    commercialAttribution: false,
                    commercializerChecker: address(0),
                    commercializerCheckerData: EMPTY_BYTES,
                    commercialRevShare: 0,
                    derivativesAllowed: true,
                    derivativesAttribution: true,
                    derivativesApproval: false,
                    derivativesReciprocal: true,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            ),
            royaltyPolicy: address(0),
            royaltyData: abi.encode(uint256(0)),
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
        return module.getPolicyId(policy);
    }

    function commercialUse(
        uint256 mintingFee,
        address mintingFeeToken
    ) internal returns (RegisterPILPolicyParams memory) {
        return
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: address(0),
                mintingFee: mintingFee,
                mintingFeeToken: mintingFeeToken,
                policy: PILPolicy({
                    attribution: true,
                    commercialUse: true,
                    commercialAttribution: true,
                    commercializerChecker: address(0),
                    commercializerCheckerData: EMPTY_BYTES,
                    commercialRevShare: 0,
                    derivativesAllowed: true,
                    derivativesAttribution: false,
                    derivativesApproval: false,
                    derivativesReciprocal: false,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            });
    }

    function getCommercialUseId(
        ILicensingModule module,
        address pilFramework,
        uint256 mintingFee,
        address mintingFeeToken
    ) internal pure returns (uint256) {
        Licensing.Policy memory policy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: pilFramework,
            frameworkData: abi.encode(
                PILPolicy({
                    attribution: true,
                    commercialUse: true,
                    commercialAttribution: true,
                    commercializerChecker: address(0),
                    commercializerCheckerData: EMPTY_BYTES,
                    commercialRevShare: 0,
                    derivativesAllowed: true,
                    derivativesAttribution: false,
                    derivativesApproval: false,
                    derivativesReciprocal: false,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            ),
            royaltyPolicy: address(0),
            royaltyData: abi.encode(uint256(0)),
            mintingFee: mintingFee,
            mintingFeeToken: mintingFeeToken
        });
        return module.getPolicyId(policy);
    }

    function commercialRemixingWithAttribution(
        uint32 commercialRevShare,
        address royaltyPolicy
    ) internal returns (RegisterPILPolicyParams memory) {
        return
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: royaltyPolicy,
                mintingFee: 0,
                mintingFeeToken: address(0),
                policy: PILPolicy({
                    attribution: true,
                    commercialUse: true,
                    commercialAttribution: true,
                    commercializerChecker: address(0),
                    commercializerCheckerData: EMPTY_BYTES,
                    commercialRevShare: commercialRevShare,
                    derivativesAllowed: true,
                    derivativesAttribution: true,
                    derivativesApproval: false,
                    derivativesReciprocal: true,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            });
    }

    function getCommercialRemixingWithAttributionId(
        ILicensingModule module,
        address pilFramework,
        uint32 commercialRevShare,
        address royaltyPolicy
    ) internal pure returns (uint256) {
        Licensing.Policy memory policy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: pilFramework,
            frameworkData: abi.encode(
                PILPolicy({
                    attribution: true,
                    commercialUse: true,
                    commercialAttribution: true,
                    commercializerChecker: address(0),
                    commercializerCheckerData: EMPTY_BYTES,
                    commercialRevShare: commercialRevShare,
                    derivativesAllowed: true,
                    derivativesAttribution: true,
                    derivativesApproval: false,
                    derivativesReciprocal: true,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            ),
            royaltyPolicy: address(0),
            royaltyData: abi.encode(commercialRevShare),
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
        return module.getPolicyId(policy);
    }
}
