// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { UMLPolicy, RegisterUMLPolicyParams } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { TestHelper } from "test/foundry/utils/TestHelper.sol";

contract UMLPolicyFrameworkTest is TestHelper {
    UMLPolicyFrameworkManager internal umlFramework;

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipOwner = vm.addr(1);
    address public licenseHolder = address(0x101);

    function setUp() public override {
        TestHelper.setUp();

        nft = erc721.ape;

        umlFramework = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "UMLPolicyFrameworkManager",
            licenseUrl
        );

        licensingModule.registerPolicyFrameworkManager(address(umlFramework));

        nft.mintId(ipOwner, 1);
        nft.mintId(ipOwner, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);
    }

    function test_UMLPolicyFrameworkManager__valuesSetCorrectly() public {
        string[] memory territories = new string[](2);
        territories[0] = "test1";
        territories[1] = "test2";
        string[] memory distributionChannels = new string[](1);
        distributionChannels[0] = "test3";
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.policy.territories = territories;
        inputA.policy.distributionChannels = distributionChannels;
        uint256 policyId = umlFramework.registerPolicy(inputA);
        UMLPolicy memory policy = umlFramework.getUMLPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(inputA.policy)));
    }

    /////////////////////////////////////////////////////////////
    //////              COMMERCIAL USE TERMS               //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager__commercialUse_disallowed_revert_settingIncompatibleTerms() public {
        // If no commercial values allowed
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.policy.commercialAttribution = true;
        // commercialAttribution = true should revert
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddAttribution.selector);
        umlFramework.registerPolicy(inputA);
        // Non empty commercializers should revert
        inputA.policy.commercialAttribution = false;
        inputA.policy.commercializers = new string[](1);
        inputA.policy.commercializers[0] = "test";
        vm.expectRevert(
            UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers.selector
        );
        umlFramework.registerPolicy(inputA);
        // No rev share should be set; revert
        inputA.policy.commercializers = new string[](0);
        inputA.policy.commercialRevShare = 1;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddRevShare.selector);
        umlFramework.registerPolicy(inputA);
    }

    function test_UMLPolicyFrameworkManager__commercialUse_valuesSetCorrectly() public {
        string[] memory commercializers = new string[](2);
        commercializers[0] = "test1";
        commercializers[1] = "test2";
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.policy.commercialAttribution = true;
        inputA.policy.commercializers = commercializers;
        uint256 policyId = umlFramework.registerPolicy(inputA);
        UMLPolicy memory policy = umlFramework.getUMLPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(inputA.policy)));
    }

    function test_UMLPolicyFrameworkManager__derivatives_notAllowed_revert_settingIncompatibleTerms() public {
        // If no derivative values allowed
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: false,
            reciprocal: false,
            commercialRevShare: 123123
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.policy.derivativesAttribution = true;
        // derivativesAttribution = true should revert
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution.selector);
        umlFramework.registerPolicy(inputA);
        // Requesting approval for derivatives should revert
        inputA.policy.derivativesAttribution = false;
        inputA.policy.derivativesApproval = true;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddApproval.selector);
        umlFramework.registerPolicy(inputA);
        // Setting reciprocal license should revert
        inputA.policy.derivativesApproval = false;
        inputA.policy.derivativesReciprocal = true;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal.selector);
        umlFramework.registerPolicy(inputA);
    }

    function test_UMLPolicyFrameworkManager__derivatives_valuesSetCorrectly() public {
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.policy.derivativesAttribution = true;
        uint256 policyId = umlFramework.registerPolicy(inputA);
        UMLPolicy memory policy = umlFramework.getUMLPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(inputA.policy)));
    }

    /////////////////////////////////////////////////////////////
    //////                  APPROVAL TERMS                 //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager_derivatives_withApproval_revert_linkNotApproved() public {
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.policy.derivativesApproval = true;
        uint256 policyId = umlFramework.registerPolicy(inputA);
        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, ipOwner, "");
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.prank(licenseRegistry.licensorIpId(licenseId));
        umlFramework.setApproval(licenseId, ipId2, false);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.expectRevert(Errors.LicensingModule__LinkParentParamFailed.selector);
        vm.prank(ipOwner);
        licensingModule.linkIpToParents(licenseIds, ipId2, "");
    }

    function test_UMLPolicyFrameworkManager__derivatives_withApproval_linkApprovedIpId() public {
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 0
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.policy.derivativesApproval = true;
        uint256 policyId = umlFramework.registerPolicy(inputA);

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, ipOwner, "");
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.prank(licenseRegistry.licensorIpId(licenseId));
        umlFramework.setApproval(licenseId, ipId2, true);
        assertTrue(umlFramework.isDerivativeApproved(licenseId, ipId2));

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.prank(ipOwner);
        licensingModule.linkIpToParents(licenseIds, ipId2, "");
        assertTrue(licensingModule.isParent(ipId1, ipId2));
    }

    /////////////////////////////////////////////////////////////
    //////                  TRANSFER TERMS                 //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager__transferrable() public {
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.transferable = true;
        uint256 policyId = umlFramework.registerPolicy(inputA);
        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 0);
        assertEq(licenseRegistry.balanceOf(licenseHolder2, licenseId), 1);
    }

    function test_UMLPolicyFrameworkManager__nonTransferrable_revertIfTransferExceptFromLicensor() public {
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 123123
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        inputA.transferable = false;
        uint256 policyId = umlFramework.registerPolicy(inputA);
        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.startPrank(licenseHolder);
        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        vm.stopPrank();
    }
}
