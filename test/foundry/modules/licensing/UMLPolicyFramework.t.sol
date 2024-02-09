// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { UMLPolicy } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
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

    function test_UMLPolicyFrameworkManager_getPolicyId() public {
        _mapUMLPolicySimple({name: "pol", commercial: true, derivatives: false, reciprocal: false, commercialRevShare: 0, derivativesRevShare: 0});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        assertEq(umlFramework.getPolicyId(umlPolicy), policyId);
    }

    function test_UMLPolicyFrameworkManager__valuesSetCorrectly() public {
        string[] memory territories = new string[](2);
        territories[0] = "test1";
        territories[1] = "test2";
        string[] memory distributionChannels = new string[](1);
        distributionChannels[0] = "test3";

        _mapUMLPolicySimple({name: "pol", commercial: true, derivatives: false, reciprocal: false, commercialRevShare: 0, derivativesRevShare: 0});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.attribution = true;
        umlPolicy.transferable = false;
        umlPolicy.commercialAttribution = true;
        umlPolicy.territories = territories;
        umlPolicy.distributionChannels = distributionChannels;

        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    /////////////////////////////////////////////////////////////
    //////              COMMERCIAL USE TERMS               //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager__commercialUse_disallowed_revert_settingIncompatibleTerms() public {
        // If no commercial values allowed
        _mapUMLPolicySimple({name: "pol", commercial: false, derivatives: false, reciprocal: false, commercialRevShare: 0, derivativesRevShare: 0});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.commercialAttribution = true;
        // commercialAttribution = true should revert
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddAttribution.selector);
        umlFramework.registerPolicy(umlPolicy);
        // Non empty commercializers should revert
        umlPolicy.commercialAttribution = false;
        umlPolicy.commercializers = new string[](1);
        umlPolicy.commercializers[0] = "test";
        vm.expectRevert(
            UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers.selector
        );
        umlFramework.registerPolicy(umlPolicy);
        // No rev share should be set; revert
        umlPolicy.commercializers = new string[](0);
        umlPolicy.commercialRevShare = 1;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddRevShare.selector);
        umlFramework.registerPolicy(umlPolicy);
        // No rev share should be set for derivatives either; revert
        umlPolicy.commercialRevShare = 0;
        umlPolicy.derivativesRevShare = 1;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddDerivRevShare.selector);
        umlFramework.registerPolicy(umlPolicy);
    }

    function test_UMLPolicyFrameworkManager__commercialUse_valuesSetCorrectly() public {
        string[] memory commercializers = new string[](2);
        commercializers[0] = "test1";
        commercializers[1] = "test2";
        _mapUMLPolicySimple({name: "pol", commercial: true, derivatives: false, reciprocal: false, commercialRevShare: 123123, derivativesRevShare: 1});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.commercialAttribution = true;
        umlPolicy.commercializers = commercializers;

        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    function test_UMLPolicyFrameworkManager__derivatives_notAllowed_revert_settingIncompatibleTerms() public {
        // If no derivative values allowed
        _mapUMLPolicySimple({name: "pol", commercial: true, derivatives: false, reciprocal: false, commercialRevShare: 123123, derivativesRevShare: 1});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.commercialAttribution = true;
        umlPolicy.derivativesAttribution = true;
        // derivativesAttribution = true should revert
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution.selector);
        umlFramework.registerPolicy(umlPolicy);
        // Requesting approval for derivatives should revert
        umlPolicy.derivativesAttribution = false;
        umlPolicy.derivativesApproval = true;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddApproval.selector);
        umlFramework.registerPolicy(umlPolicy);
        // Setting reciprocal license should revert
        umlPolicy.derivativesApproval = false;
        umlPolicy.derivativesReciprocal = true;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal.selector);
        umlFramework.registerPolicy(umlPolicy);
        // No rev share should be set for derivatives either; revert
        umlPolicy.derivativesReciprocal = false;
        umlPolicy.derivativesRevShare = 1;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddRevShare.selector);
        umlFramework.registerPolicy(umlPolicy);
    }

    function test_UMLPolicyFrameworkManager__derivatives_valuesSetCorrectly() public {
        _mapUMLPolicySimple({name: "pol", commercial: true, derivatives: true, reciprocal: true, commercialRevShare: 123123, derivativesRevShare: 1});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.derivativesAttribution = true;
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    /////////////////////////////////////////////////////////////
    //////                  APPROVAL TERMS                 //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager_derivatives_withApproval_revert_linkNotApproved() public {
        _mapUMLPolicySimple({name: "pol", commercial: false, derivatives: true, reciprocal: true, commercialRevShare: 0, derivativesRevShare: 0});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.transferable = false;
        umlPolicy.derivativesApproval = true;
        umlPolicy.royaltyPolicy = address(0);
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, ipOwner);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.prank(licenseRegistry.licensorIpId(licenseId));
        umlFramework.setApproval(licenseId, ipId2, false);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.expectRevert(Errors.LicensingModule__LinkParentParamFailed.selector);
        vm.prank(ipOwner);
        licensingModule.linkIpToParents(licenseIds, ipId2, 0);
    }

    function test_UMLPolicyFrameworkManager__derivatives_withApproval_linkApprovedIpId() public {
        _mapUMLPolicySimple({name: "pol", commercial: false, derivatives: true, reciprocal: false, commercialRevShare: 0, derivativesRevShare: 0});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.transferable = false;
        umlPolicy.derivativesApproval = true;
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, ipOwner);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        vm.prank(ipOwner);
        licenseRegistry.safeTransferFrom(ipOwner, licenseHolder, licenseId, 1, "");

        vm.prank(licenseRegistry.licensorIpId(licenseId));
        umlFramework.setApproval(licenseId, ipId2, true);
        assertTrue(umlFramework.isDerivativeApproved(licenseId, ipId2));

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.prank(ipOwner);
        licensingModule.linkIpToParents(licenseIds, ipId2, 0);
        assertTrue(licensingModule.isParent(ipId1, ipId2));
    }

    /////////////////////////////////////////////////////////////
    //////                  TRANSFER TERMS                 //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager__transferrable() public {
        _mapUMLPolicySimple({name: "pol", commercial: false, derivatives: true, reciprocal: false, commercialRevShare: 0, derivativesRevShare: 0});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.transferable = true;
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 0);
        assertEq(licenseRegistry.balanceOf(licenseHolder2, licenseId), 1);
    }

    function test_UMLPolicyFrameworkManager__nonTransferrable_revertIfTransferExceptFromLicensor() public {
        _mapUMLPolicySimple({name: "pol", commercial: false, derivatives: true, reciprocal: false, commercialRevShare: 0, derivativesRevShare: 0});
        UMLPolicy memory umlPolicy = _getMappedUmlPolicy("pol");
        umlPolicy.transferable = false;
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.startPrank(licenseHolder);
        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        vm.stopPrank();
    }
}
