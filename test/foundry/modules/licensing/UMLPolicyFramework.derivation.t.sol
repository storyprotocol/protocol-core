// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { TestHelper } from "test/foundry/utils/TestHelper.sol";

contract UMLPolicyFrameworkCompatibilityTest is TestHelper {
    UMLPolicyFrameworkManager internal umlFramework;

    string internal licenseUrl = "https://example.com/license";
    address internal bob = address(0x111);
    address internal ipId1;
    address internal alice = address(0x222);
    address internal ipId2;
    address internal don = address(0x333);

    modifier withUMLPolicySimple(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal
    ) {
        _mapUMLPolicySimple(name, commercial, derivatives, reciprocal, 100);
        _addUMLPolicyFromMapping(name, address(umlFramework));
        _;
    }

    modifier withAliceOwningDerivativeIp2(string memory policyName) {
        mockRoyaltyPolicyLS.setMinRoyalty(ipId1, 100);

        // Must add the policy first to set the royalty policy (if policy is commercial)
        // Otherwise, minting license will fail because there's no royalty policy set for license policy,
        // AND bob (the caller) is not the owner of IPAccount 1.
        vm.startPrank(bob);
        uint256 licenseId = licensingModule.mintLicense(_getUmlPolicyId(policyName), ipId1, 1, alice, "");

        vm.startPrank(alice);
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;
        licensingModule.linkIpToParents(licenseIds, ipId2, "");
        vm.stopPrank();
        _;
    }

    function setUp() public override {
        super.setUp();

        nft = erc721.ape;
        umlFramework = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "UMLPolicyFrameworkManager",
            licenseUrl
        );

        licensingModule.registerPolicyFrameworkManager(address(umlFramework));

        nft.mintId(bob, 1);
        nft.mintId(alice, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);
        vm.label(bob, "Bob");
        vm.label(alice, "Alice");
        vm.label(don, "Don");
        vm.label(ipId1, "IP1");
        vm.label(ipId2, "IP2");

        vm.label(LIQUID_SPLIT_FACTORY, "LIQUID_SPLIT_FACTORY");
        vm.label(LIQUID_SPLIT_MAIN, "LIQUID_SPLIT_MAIN");
    }

    /////////////////////////////////////////////////////////////
    //////  SETTING POLICIES IN ORIGINAL WORK (NO PARENTS) //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFramework_originalWork_bobAddsDifferentPoliciesAndAliceMints()
        public
        withUMLPolicySimple("comm_deriv", true, true, false)
        withUMLPolicySimple("comm_non_deriv", true, false, false)
    {
        // Bob can add different policies on IP1 without compatibility checks.
        vm.startPrank(bob);
        licensingModule.addPolicyToIp(ipId1, _getUmlPolicyId("comm_deriv"));
        licensingModule.addPolicyToIp(ipId1, _getUmlPolicyId("comm_non_deriv"));
        vm.stopPrank();

        bool isInherited = false;
        assertEq(licensingModule.totalPoliciesForIp(isInherited, ipId1), 2);
        assertTrue(
            licensingModule.isPolicyIdSetForIp(isInherited, ipId1, _getUmlPolicyId("comm_deriv")),
            "comm_deriv not set"
        );
        assertTrue(
            licensingModule.isPolicyIdSetForIp(isInherited, ipId1, _getUmlPolicyId("comm_non_deriv")),
            "comm_non_deriv not set"
        );

        mockRoyaltyPolicyLS.setMinRoyalty(ipId1, 100);

        // Others can mint licenses to make derivatives of IP1 from each different policy,
        // as long as they pass the verifications
        uint256 licenseId1 = licensingModule.mintLicense(_getUmlPolicyId("comm_deriv"), ipId1, 1, don, "");
        assertEq(licenseRegistry.balanceOf(don, licenseId1), 1, "Don doesn't have license1");

        uint256 licenseId2 = licensingModule.mintLicense(_getUmlPolicyId("comm_non_deriv"), ipId1, 1, don, "");
        assertEq(licenseRegistry.balanceOf(don, licenseId2), 1, "Don doesn't have license2");
    }

    function test_UMLPolicyFramework_originalWork_bobMintsWithDifferentPolicies()
        public
        withUMLPolicySimple("comm_deriv", true, true, false)
        withUMLPolicySimple("comm_non_deriv", true, false, false)
    {
        mockRoyaltyPolicyLS.setMinRoyalty(ipId1, 100);

        // Bob can add different policies on IP1 without compatibility checks.
        vm.startPrank(bob);
        uint256 licenseId1 = licensingModule.mintLicense(_getUmlPolicyId("comm_deriv"), ipId1, 2, don, "");
        assertEq(licenseRegistry.balanceOf(don, licenseId1), 2, "Don doesn't have license1");

        uint256 licenseId2 = licensingModule.mintLicense(_getUmlPolicyId("comm_non_deriv"), ipId1, 1, don, "");
        assertEq(licenseRegistry.balanceOf(don, licenseId2), 1, "Don doesn't have license2");
        vm.stopPrank();
    }

    function test_UMLPolicyFramework_originalWork_bobSetsPoliciesThenCompatibleParent()
        public
        withUMLPolicySimple("comm_deriv", true, true, false)
        withUMLPolicySimple("comm_non_deriv", true, false, false)
    {
        // TODO: This works if all policies compatible.
        // Can bob disable some policies?
    }

    /////////////////////////////////////////////////////////////////
    //////  SETTING POLICIES IN DERIVATIVE WORK (WITH PARENTS) //////
    /////////////////////////////////////////////////////////////////

    function test_UMLPolicyFramework_derivative_revert_cantMintDerivativeOfDerivative()
        public
        withUMLPolicySimple("comm_non_deriv", true, false, false)
        withAliceOwningDerivativeIp2("comm_non_deriv")
    {
        mockRoyaltyPolicyLS.setMinRoyalty(ipId2, 100);

        vm.expectRevert(Errors.LicensingModule__MintLicenseParamFailed.selector);
        vm.startPrank(don);
        licensingModule.mintLicense(_getUmlPolicyId("comm_non_deriv"), ipId2, 1, don, "");

        vm.expectRevert(Errors.LicensingModule__MintLicenseParamFailed.selector);
        vm.startPrank(alice);
        licensingModule.mintLicense(_getUmlPolicyId("comm_non_deriv"), ipId2, 1, alice, "");
    }

    function test_UMLPolicyFramework_derivative_revert_AliceCantSetPolicyOnDerivativeOfDerivative()
        public
        withUMLPolicySimple("comm_non_deriv", true, false, false)
        withUMLPolicySimple("comm_deriv", true, true, false)
        withAliceOwningDerivativeIp2("comm_non_deriv")
    {
        mockRoyaltyPolicyLS.setMinRoyalty(ipId2, 100);

        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddPolicy.selector);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId2, _getUmlPolicyId("comm_deriv"));

        _mapUMLPolicySimple("other_policy", true, true, false, 100);
        _getMappedUmlPolicy("other_policy").attribution = false;
        _addUMLPolicyFromMapping("other_policy", address(umlFramework));

        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddPolicy.selector);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId2, _getUmlPolicyId("other_policy"));
    }

    /////////////////////////////////////////////////////////////////
    //////                RECIPROCAL DERIVATIVES               //////
    /////////////////////////////////////////////////////////////////

    function test_UMLPolicyFramework_reciprocal_DonMintsLicenseFromIp2()
        public
        withUMLPolicySimple("comm_reciprocal", true, true, true)
        withAliceOwningDerivativeIp2("comm_reciprocal")
    {
        mockRoyaltyPolicyLS.setMinRoyalty(ipId2, 100);

        vm.prank(don);
        uint256 licenseId = licensingModule.mintLicense(_getUmlPolicyId("comm_reciprocal"), ipId2, 1, don, "");
        assertEq(licenseRegistry.balanceOf(don, licenseId), 1, "Don doesn't have license");
    }

    function test_UMLPolicyFramework_reciprocal_AliceMintsLicenseForP1inIP2()
        public
        withUMLPolicySimple("comm_reciprocal", true, true, true)
        withAliceOwningDerivativeIp2("comm_reciprocal")
    {
        mockRoyaltyPolicyLS.setMinRoyalty(ipId2, 100);

        vm.prank(alice);
        uint256 licenseId = licensingModule.mintLicense(_getUmlPolicyId("comm_reciprocal"), ipId2, 1, alice, "");
        assertEq(licenseRegistry.balanceOf(alice, licenseId), 1, "Alice doesn't have license");
    }

    function test_UMLPolicyFramework_reciprocal_revert_AliceTriesToSetPolicyInReciprocalDeriv()
        public
        withUMLPolicySimple("comm_reciprocal", true, true, true)
        withUMLPolicySimple("other_policy", true, true, false)
        withAliceOwningDerivativeIp2("comm_reciprocal")
    {
        mockRoyaltyPolicyLS.setMinRoyalty(ipId2, 100);

        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddPolicy.selector);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId2, _getUmlPolicyId("other_policy"));

        vm.expectRevert(Errors.LicensingModule__DerivativesCannotAddPolicy.selector);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId2, _getUmlPolicyId("comm_reciprocal"));
    }
}
