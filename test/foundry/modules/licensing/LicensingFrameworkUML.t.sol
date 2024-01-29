// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors } from "contracts/lib/Errors.sol";

import { LicensingFrameworkUML, UMLv1Policy } from "contracts/modules/licensing/LicensingFrameworkUML.sol";

import "forge-std/console2.sol";

contract LicensingFrameworkUMLTest is Test {

    LicenseRegistry public registry;
    Licensing.Framework public framework;

    LicensingFrameworkUML public umlFramework;
    uint256 public frameworkId;

    string public licenseUrl = "https://example.com/license";
    address public ipId1 = address(0x111);
    address public ipId2 = address(0x222);
    address public licenseHolder = address(0x101);
    string[] public emptyStringArray = new string[](0);

    function setUp() public {
        registry = new LicenseRegistry();
        umlFramework = new LicensingFrameworkUML(address(registry), licenseUrl);
        frameworkId = umlFramework.register();
    }

    function test_ParamVerifier_commercialUse_disallowed_revert_settingIncompatibleTerms() public {
        // TODO
    }

    function test_ParamVerifier_commercialUse_setAllowedCommercializers() public {
        // TODO
    }

    function test_ParamVerifier_commercialUse_setAllowedWithAttribution() public {
        // TODO
    }

    function test_ParamVerifier_commercialUse_revenueShareSetOnLinking() public {
        // TODO
    }

    function test_ParamVerifier_derivatives_notAllowed_revert_creating2ndDerivative() public {
        // TODO
    }

    function test_ParamVerifier_derivatives_notAllowed_revert_settingIncompatibleTerms() public {
        // TODO
    }

    function test_ParamVerifier_derivatives_setAllowedWithAttribution() public {
        // TODO
    }

    function test_LicensingFrameworkUML_derivatives_setReciprocal() public {
        // TODO
    }

    function test_LicensingFrameworkUML_derivatives_setRevenueShareValue() public {
        // TODO
    }

    function test_LicensingFrameworkUML_derivatives_setRevenueShareWhenLinking2ndDerivative() public {
        // TODO
    }

    function test_LicensingFrameworkUML_derivativesWithApproval_revert_linkNotApproved() public {
        uint256 policyId = umlFramework.addPolicy(UMLv1Policy({
            attribution: false,
            commercialUse: false,
            commercialAttribution: false,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: true,
            derivativesAttribution: false,
            derivativesApproval: true,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray
        }));
        console2.log("policyId", policyId);
        registry.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));
        umlFramework.setApproval(licenseId, ipId2, false);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.expectRevert(Errors.LicenseRegistry__LinkParentParamFailed.selector);
        registry.linkIpToParent(licenseId, ipId2, licenseHolder);
    }

    function test_LicensingFrameworkUML_derivatives_withApproval_linkApprovedIpId() public {
        uint256 policyId = umlFramework.addPolicy(UMLv1Policy({
            attribution: false,
            commercialUse: false,
            commercialAttribution: false,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: true,
            derivativesAttribution: false,
            derivativesApproval: true,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray
        }));
        registry.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));
        umlFramework.setApproval(licenseId, ipId2, true);
        assertTrue(umlFramework.isDerivativeApproved(licenseId, ipId2));

        registry.linkIpToParent(licenseId, ipId2, licenseHolder);
        assertTrue(registry.isParent(ipId1, ipId2));
    }

    function test_LicensingFrameworkUML_derivatives_withApproval_revert_approverNotLicensor() public {
        // TODO
    }

    function test_LicensingFrameworkUML_setTerritory() public {
        // TODO
    }

    function test_LicensingFrameworkUML_setChannelsOfDistribution() public {
        // TODO
    }

    function test_LicensingFrameworkUML_setAttributionInReproduction() public {
        // TODO
    }

    function test_LicensingFrameworkUML_setContentStandards() public {
        // TODO
    }

    function test_LicensingFrameworkUML_transferrable() public {
        // TODO
    }

    function test_LicensingFrameworkUML_nonTransferrable_revertIfTransferExceptFromLicensor() public {
        // TODO
    }

    function test_LicensingFrameworkUML_mintFee() public {
        // TODO
    }

    function test_tokenUri() public {
        // TODO
    }


}