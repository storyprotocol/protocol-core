// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { UMLPolicy, RegisterUMLPolicyParams } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/modules/licensing/IPolicyFrameworkManager.sol";
import { TestHelper } from "test/foundry/utils/TestHelper.sol";

contract UMLPolicyFrameworkMultiParentTest is TestHelper {
    UMLPolicyFrameworkManager internal umlFramework;
    string internal licenseUrl = "https://example.com/license";
    address internal bob = address(0x111);
    address internal ipId1;
    address internal ipId2;
    address internal ipId3;
    address internal alice = address(0x222);
    address internal ipId4;

    uint256[] internal licenses;

    mapping(address => address) internal ipIdToOwner;

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

    modifier withLicense(
        string memory policyName,
        address ipId,
        address owner
    ) {
        uint256 policyId = _getUmlPolicyId(policyName);

        Licensing.Policy memory policy = licensingModule.policy(policyId);

        vm.prank(ipIdToOwner[ipId]);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId, 1, owner, "");
        licenses.push(licenseId);
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
        nft.mintId(bob, 2);
        nft.mintId(bob, 3);
        nft.mintId(alice, 4);

        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipIdToOwner[ipId1] = bob;
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);
        ipIdToOwner[ipId2] = bob;
        ipId3 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 3);
        ipIdToOwner[ipId3] = bob;
        ipId4 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 4);
        ipIdToOwner[ipId4] = alice;
        vm.label(bob, "Bob");
        vm.label(alice, "Alice");
        vm.label(ipId1, "IP1");
        vm.label(ipId2, "IP2");
        vm.label(ipId3, "IP3");
        vm.label(ipId4, "IP4");
    }

    function test_UMLPolicyFramework_multiParent_AliceSets3Parents_SamePolicyReciprocal()
        public
        withUMLPolicySimple("reciprocal", true, true, true)
        withLicense("reciprocal", ipId1, alice)
        withLicense("reciprocal", ipId2, alice)
        withLicense("reciprocal", ipId3, alice)
    {
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
        assertEq(licensingModule.totalParentsForIpId(ipId4), 3);
        address[] memory parents = licensingModule.parentIpIds(ipId4);
        for (uint256 i = 0; i < licenses.length; i++) {
            Licensing.License memory license = licenseRegistry.license(licenses[i]);
            assertEq(parents[i], license.licensorIpId);
        }
        assertEq(licensingModule.totalPoliciesForIp(false, ipId4), 0);
        assertEq(licensingModule.totalPoliciesForIp(true, ipId4), 1);
        assertTrue(licensingModule.isPolicyIdSetForIp(true, ipId4, _getUmlPolicyId("reciprocal")));
    }

    function test_UMLPolicyFramework_multiParent_revert_AliceSets3Parents_OneNonReciprocal()
        public
        withUMLPolicySimple("reciprocal", true, true, true)
        withUMLPolicySimple("non_reciprocal", true, true, false)
        withLicense("reciprocal", ipId1, alice)
        withLicense("non_reciprocal", ipId2, alice)
        withLicense("reciprocal", ipId3, alice)
    {
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__ReciprocalValueMismatch.selector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
    }

    function test_UMLPolicyFramework_multiParent_revert_AliceSets3Parents_3ReciprocalButDifferent()
        public
        withUMLPolicySimple("reciprocal", true, true, true)
        withLicense("reciprocal", ipId1, alice)
        withLicense("reciprocal", ipId2, alice)
    {
        // Save a new policy (change some value to change the policyId)
        _mapUMLPolicySimple("other", true, true, true, 100);
        _getMappedUmlPolicy("other").attribution = !_getMappedUmlPolicy("other").attribution;
        _addUMLPolicyFromMapping("other", address(umlFramework));

        mockRoyaltyPolicyLS.setMinRoyalty(ipId3, 100);
        vm.prank(ipId3);
        licenses.push(licensingModule.mintLicense(_getUmlPolicyId("other"), ipId3, 1, alice, ""));
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__ReciprocalButDifferentPolicyIds.selector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalCommercial() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;
        // Commercial use (success)
        _testSuccessCompat(inputA, inputB, 2);
    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalCommercial() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;
        // Commercial use (revert)
        inputA.policy.commercialUse = true;
        inputB.policy.commercialUse = false;
        inputB.policy.commercialRevShare = 0;
        inputB.royaltyPolicy = address(0x0);
        // TODO: passing in two different royaltyPolicy addresses
        // solhint-disable-next-line max-line-length
        _testRevertCompat(inputA, inputB, Errors.LicensingModule__IncompatibleLicensorCommercialPolicy.selector);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalDerivatives() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Derivatives (success)
        _testSuccessCompat(inputA, inputB, 2);
    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalDerivatives() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Derivatives (revert)
        inputA.policy.derivativesAllowed = true;
        inputB.policy.derivativesAllowed = !inputA.policy.derivativesAllowed;

        // TODO: passing in two different royaltyPolicy addresses
        // solhint-disable-next-line max-line-length
        _testRevertCompat(inputA, inputB, UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesValueMismatch.selector);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalTerritories() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");

        // Territories (success same)
        inputA.policy.territories = new string[](1);
        inputA.policy.territories[0] = "US";
        inputB.policy.territories = new string[](1);
        inputB.policy.territories[0] = "US";
        inputB.policy.attribution = !inputB.policy.attribution; // generates different policyId
        _testSuccessCompat(inputA, inputB, 2);

    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalTerritories() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Territories (revert)
        inputA.policy.territories = new string[](1);
        inputA.policy.territories[0] = "US";
        inputB.policy.territories = new string[](1);
        inputB.policy.territories[0] = "UK";
        _testRevertCompat(inputA, inputB, UMLFrameworkErrors.UMLPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalDistributionChannels() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");

        // Territories (success same)
        inputA.policy.distributionChannels = new string[](1);
        inputA.policy.distributionChannels[0] = "web";
        inputB.policy.distributionChannels = new string[](1);
        inputB.policy.distributionChannels[0] = "web";
        inputB.policy.attribution = !inputB.policy.attribution; // generates different policyId
        _testSuccessCompat(inputA, inputB, 2);

    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalDistributionChannels() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputB.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Distribution channels (revert)
        inputA.policy.distributionChannels = new string[](1);
        inputA.policy.distributionChannels[0] = "web";
        inputB.policy.distributionChannels = new string[](1);
        inputB.policy.distributionChannels[0] = "mobile";
        _testRevertCompat(inputA, inputB, UMLFrameworkErrors.UMLPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalContentRestrictions() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");

        // Territories (success same)
        inputA.policy.contentRestrictions = new string[](1);
        inputA.policy.contentRestrictions[0] = "web";
        inputB.policy.contentRestrictions = new string[](1);
        inputB.policy.contentRestrictions[0] = "web";
        inputB.policy.attribution = !inputB.policy.attribution; // generates different policyId
        _testSuccessCompat(inputA, inputB, 2);

    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalContentRestrictions() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputB = _getMappedUmlParams("pol_b");
        // We set some indifferents
        inputA.policy.attribution = true;
        inputB.policy.attribution = !inputA.policy.attribution;
        inputA.transferable = true;
        inputB.transferable = !inputA.transferable;

        // Content restrictions (revert)
        inputA.policy.contentRestrictions = new string[](1);
        inputA.policy.contentRestrictions[0] = "adult";
        inputB.policy.contentRestrictions = new string[](1);
        inputB.policy.contentRestrictions[0] = "child";
        _testRevertCompat(inputA, inputB, UMLFrameworkErrors.UMLPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function _test_register_mint_AB(
        RegisterUMLPolicyParams memory inputA,
        RegisterUMLPolicyParams memory inputB
    ) internal returns (uint256 polAId, uint256 polBId) {

        polAId = umlFramework.registerPolicy(inputA);
        vm.prank(ipId1);
        licenses.push(licensingModule.mintLicense(polAId, ipId1, 1, alice, ""));

        polBId = umlFramework.registerPolicy(inputB);
        vm.prank(ipId2);
        licenses.push(licensingModule.mintLicense(polBId, ipId2, 2, alice, ""));
    }

    function _testRevertCompat(
        RegisterUMLPolicyParams memory inputA,
        RegisterUMLPolicyParams memory inputB,
        bytes4 errorSelector
    ) internal {
        _test_register_mint_AB(inputA, inputB);

        vm.expectRevert(errorSelector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
        licenses = new uint256[](0);
    }

    function _testSuccessCompat(
        RegisterUMLPolicyParams memory inputA,
        RegisterUMLPolicyParams memory inputB,
        uint256 expectedPolicies
    ) internal {
        (uint256 polAId, uint256 polBId) = _test_register_mint_AB(inputA, inputB);

        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, "");
        assertEq(licensingModule.totalParentsForIpId(ipId4), 2);

        address[] memory parents = licensingModule.parentIpIds(ipId4);
        for (uint256 i = 0; i < licenses.length; i++) {
            Licensing.License memory license = licenseRegistry.license(licenses[i]);
            assertEq(parents[i], license.licensorIpId);
        }
        assertEq(licensingModule.totalPoliciesForIp(false, ipId4), 0);
        assertEq(licensingModule.totalPoliciesForIp(true, ipId4), expectedPolicies);
        assertTrue(licensingModule.isPolicyIdSetForIp(true, ipId4, polAId));
        assertTrue(licensingModule.isPolicyIdSetForIp(true, ipId4, polBId));
        licenses = new uint256[](0); // To call this function multiple times
    }
}
