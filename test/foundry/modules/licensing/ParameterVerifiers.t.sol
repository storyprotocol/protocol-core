// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { DerivWithApprovalPV } from "contracts/modules/licensing/parameters/DerivWithApprovalPV.sol";

contract LicenseRegistryTest is Test {
    using Strings for *;
    using ShortStrings for *;

    LicenseRegistry public registry;
    Licensing.Framework public framework;

    DerivWithApprovalPV public derivWithApprovalPv;

    Licensing.FrameworkCreationParams public fwParams;

    string public licenseUrl = "https://example.com/license";
    address public ipId1 = address(0x111);
    address public ipId2 = address(0x222);
    address public licenseHolder = address(0x101);

    function setUp() public {
        registry = new LicenseRegistry("https://example.com/{id}.json");
        derivWithApprovalPv = new DerivWithApprovalPV(address(registry));
        _addFramework();
    }

    function _addFramework() private {
        IParamVerifier[] memory parameters = new IParamVerifier[](1);
        parameters[0] = derivWithApprovalPv;
        bytes[] memory values = new bytes[](1);
        values[0] = abi.encode(true);

        fwParams = Licensing.FrameworkCreationParams({
            parameters: parameters,
            defaultValues: values,
            licenseUrl: licenseUrl
        });
        registry.addLicenseFramework(fwParams);
    }

    function _createPolicy(
        bool derivatives,
        bool commercial,
        IParamVerifier verif,
        bytes memory data
    ) internal returns (Licensing.Policy memory pol) {
        pol = Licensing.Policy({
            frameworkId: 1,
            commercialUse: commercial,
            derivatives: derivatives,
            paramNames: new bytes32[](1),
            paramValues: new bytes[](1)
        });
        pol.paramNames[0] = verif.name();
        pol.paramValues[0] = data;
        return pol;
    }

    function test_ParamVerifier_commercialUse_disallowed_revert_settingIncompatibleTerms public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifier_commercialUse_setAllowedCommercializers() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifier_commercialUse_setAllowedWithAttribution() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifier_commercialUse_revenueShareSetOnLinking() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifier_derivatives_notAllowed_revert_creating2ndDerivative() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifier_derivatives_notAllowed_revert_settingIncompatibleTerms public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifier_derivatives_setAllowedWithAttribution() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_derivatives_setReciprocal() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_derivatives_setRevenueShareValue() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_derivatives_setRevenueShareWhenLinking2ndDerivative() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_derivativesWithApproval_revert_linkNotApproved() public {
        Licensing.Policy memory pol = _createPolicy(true, false, derivWithApprovalPv, abi.encode(true));
        uint256 policyId = registry.addPolicy(pol);
        registry.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        
        assertFalse(derivWithApprovalPv.isDerivativeApproved(licenseId, ipId1));
        derivWithApprovalPv.setApproval(licenseId, false);
        assertFalse(derivWithApprovalPv.isDerivativeApproved(licenseId, ipId1));

        vm.expectRevert(
            Errors.LicenseRegistry__ParamVerifierFailed(
                param.verifier.name(),
                address(param.verifier)
            );
        );
        registry.linkIpToParent(licenseId, ipId2, licenseHolder);
    }
    function test_ParamVerifiers_derivatives_withApproval_linkApprovedIpId() public {
        Licensing.Policy memory pol = _createPolicy(true, false, derivWithApprovalPv, abi.encode(true));
        uint256 policyId = registry.addPolicy(pol);
        registry.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        
        assertFalse(derivWithApprovalPv.isDerivativeApproved(licenseId, ipId1));
        derivWithApprovalPv.setApproval(licenseId, true);
        assertTrue(derivWithApprovalPv.isDerivativeApproved(licenseId, ipId1));

        registry.linkIpToParent(licenseId, ipId2, licenseHolder);
        assertTrue(registry.isParent(ipId1, ipId2));
    }

    function test_ParamVerifiers_derivatives_withApproval_revert_approverNotLicensor() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_setTerritory() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_setChannelsOfDistribution() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_setAttributionInReproduction() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_setContentStandards() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_transferrable() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_nonTransferrable_revertIfTransferExceptFromLicensor() public {
        assertFalse(true, "not implemented");
    }

    function test_ParamVerifiers_mintFee() public {
        assertFalse(true, "not implemented");
    }

    function test_tokenUri() public {
        assertFalse(true, "not implemented");
    }


}
