// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { UMLPolicy } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/modules/licensing/IPolicyFrameworkManager.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.sol";

contract UMLPolicyFrameworkMultiParentTest is BaseTest {
    UMLPolicyFrameworkManager internal umlFramework;
    string internal licenseUrl = "https://example.com/license";
    address internal ipId1;
    address internal ipId2;
    address internal ipId3;
    address internal ipId4;

    uint256[] internal licenses;

    mapping(address => address) internal ipIdToOwner;

    modifier withUMLPolicySimple(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal
    ) {
        _mapUMLPolicySimple(name, commercial, derivatives, reciprocal, 100, 100);
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
        uint32 minRoyalty = IPolicyFrameworkManager(policy.policyFramework).getCommercialRevenueShare(policyId);
        mockRoyaltyPolicyLS.setMinRoyalty(ipId, minRoyalty);

        vm.prank(ipIdToOwner[ipId]);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId, 1, owner);
        licenses.push(licenseId);
        _;
    }

    function setUp() public override {
        BaseTest.setUp();
        buildDeployRegistryCondition(DeployRegistryCondition({ licenseRegistry: true, moduleRegistry: false }));
        buildDeployModuleCondition(
            DeployModuleCondition({
                registrationModule: false,
                disputeModule: false,
                royaltyModule: false,
                taggingModule: false,
                licensingModule: true
            })
        );
        deployConditionally();
        postDeploymentSetup();

        // Call `getXXX` here to either deploy mock or use real contracted deploy via the
        // deployConditionally() call above.
        // TODO: three options, auto/mock/real in deploy condition, so no need to call getXXX
        accessController = IAccessController(getAccessController());
        licensingModule = ILicensingModule(getLicensingModule());
        royaltyModule = IRoyaltyModule(getRoyaltyModule());

        umlFramework = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "UMLPolicyFrameworkManager",
            licenseUrl
        );

        licensingModule.registerPolicyFrameworkManager(address(umlFramework));

        mockNFT.mintId(bob, 1);
        mockNFT.mintId(bob, 2);
        mockNFT.mintId(bob, 3);
        mockNFT.mintId(alice, 4);

        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 1);
        ipIdToOwner[ipId1] = bob;
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 2);
        ipIdToOwner[ipId2] = bob;
        ipId3 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 3);
        ipIdToOwner[ipId3] = bob;
        ipId4 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 4);
        ipIdToOwner[ipId4] = alice;
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
        licensingModule.linkIpToParents(licenses, ipId4, 0);
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
        licensingModule.linkIpToParents(licenses, ipId4, 0);
    }

    function test_UMLPolicyFramework_multiParent_revert_AliceSets3Parents_3ReciprocalButDifferent()
        public
        withUMLPolicySimple("reciprocal", true, true, true)
        withLicense("reciprocal", ipId1, alice)
        withLicense("reciprocal", ipId2, alice)
    {
        // Save a new policy (change some value to change the policyId)
        _mapUMLPolicySimple("other", true, true, true, 100, 100);
        _getMappedUmlPolicy("other").attribution = !_getMappedUmlPolicy("other").attribution;
        _addUMLPolicyFromMapping("other", address(umlFramework));

        mockRoyaltyPolicyLS.setMinRoyalty(ipId3, 100);
        vm.prank(ipId3);
        licenses.push(licensingModule.mintLicense(_getUmlPolicyId("other"), ipId3, 1, alice));
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__ReciprocalButDifferentPolicyIds.selector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, 0);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalCommercial() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");
        // We set some indifferents
        polA.attribution = true;
        polB.attribution = !polA.attribution;
        polA.transferable = true;
        polB.transferable = !polA.transferable;
        // Commercial use (success)
        _testSuccessCompat(polA, polB, 2);
    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalCommercial() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");
        // We set some indifferents
        polA.attribution = true;
        polB.attribution = !polA.attribution;
        polA.transferable = true;
        polB.transferable = !polA.transferable;
        // Commercial use (revert)
        polA.commercialUse = true;
        polB.commercialUse = false;
        polB.commercialRevShare = 0;
        polB.derivativesRevShare = 0;
        polB.royaltyPolicy = address(0x0);
        // TODO: passing in two different royaltyPolicy addresses
        // solhint-disable-next-line max-line-length
        // _testRevertCompat(polA, polB, UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialValueMismatch.selector);
        _testRevertCompat(polA, polB, Errors.LicensingModule__IncompatibleLicensorCommercialPolicy.selector);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalDerivatives() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");
        // We set some indifferents
        polA.attribution = true;
        polB.attribution = !polA.attribution;
        polA.transferable = true;
        polB.transferable = !polA.transferable;

        // Derivatives (success)
        _testSuccessCompat(polA, polB, 2);
    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalDerivatives() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");
        // We set some indifferents
        polA.attribution = true;
        polB.attribution = !polA.attribution;
        polA.transferable = true;
        polB.transferable = !polA.transferable;

        // Derivatives (revert)
        polA.derivativesAllowed = true;
        polB.derivativesAllowed = !polA.derivativesAllowed;
        polB.derivativesRevShare = 0;

        // TODO: passing in two different royaltyPolicy addresses
        // solhint-disable-next-line max-line-length
        // _testRevertCompat(polA, polB, UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesValueMismatch.selector);
        _testRevertCompat(polA, polB, Errors.LicensingModule__IncompatibleRoyaltyPolicyDerivativeRevShare.selector);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalTerritories() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");

        // Territories (success same)
        polA.territories = new string[](1);
        polA.territories[0] = "US";
        polB.territories = new string[](1);
        polB.territories[0] = "US";
        polB.attribution = !polB.attribution; // generates different policyId
        _testSuccessCompat(polA, polB, 2);

        // Territories (success empty)
        // polA.territories = new string[](0);
        // polB.territories = new string[](0);
        // polB.transferable = !polB.transferable; // generates different policyId
        // vm.expectRevert(Errors.RoyaltyModule__AlreadySetRoyaltyPolicy.selector);
        // _testSuccessCompat(polA, polB, 4);
    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalTerritories() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");
        // We set some indifferents
        polA.attribution = true;
        polB.attribution = !polA.attribution;
        polA.transferable = true;
        polB.transferable = !polA.transferable;

        // Territories (revert)
        polA.territories = new string[](1);
        polA.territories[0] = "US";
        polB.territories = new string[](1);
        polB.territories[0] = "UK";
        _testRevertCompat(polA, polB, UMLFrameworkErrors.UMLPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalDistributionChannels() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");

        // Territories (success same)
        polA.distributionChannels = new string[](1);
        polA.distributionChannels[0] = "web";
        polB.distributionChannels = new string[](1);
        polB.distributionChannels[0] = "web";
        polB.attribution = !polB.attribution; // generates different policyId
        _testSuccessCompat(polA, polB, 2);

        // Territories (success empty)
        // polA.distributionChannels = new string[](0);
        // polB.distributionChannels = new string[](0);
        // polB.transferable = !polB.transferable; // generates different policyId
        // vm.expectRevert(Errors.RoyaltyModule__AlreadySetRoyaltyPolicy.selector);
        // _testSuccessCompat(polA, polB, 4);
    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalDistributionChannels() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");
        // We set some indifferents
        polA.attribution = true;
        polB.attribution = !polA.attribution;
        polA.transferable = true;
        polB.transferable = !polA.transferable;

        // Distribution channels (revert)
        polA.distributionChannels = new string[](1);
        polA.distributionChannels[0] = "web";
        polB.distributionChannels = new string[](1);
        polB.distributionChannels[0] = "mobile";
        _testRevertCompat(polA, polB, UMLFrameworkErrors.UMLPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function test_UMLPolicyFramework_multiParent_NonReciprocalContentRestrictions() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");

        // Territories (success same)
        polA.contentRestrictions = new string[](1);
        polA.contentRestrictions[0] = "web";
        polB.contentRestrictions = new string[](1);
        polB.contentRestrictions[0] = "web";
        polB.attribution = !polB.attribution; // generates different policyId
        _testSuccessCompat(polA, polB, 2);

        // Territories (success empty)
        // polA.contentRestrictions = new string[](0);
        // polB.contentRestrictions = new string[](0);
        // polB.transferable = !polB.transferable; // generates different policyId
        // vm.expectRevert(Errors.RoyaltyModule__AlreadySetRoyaltyPolicy.selector);
        // _testSuccessCompat(polA, polB, 4);
    }

    function test_UMLPolicyFramework_multiParent_revert_NonReciprocalContentRestrictions() public {
        // First we create 2 policies.
        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polA = _getMappedUmlPolicy("pol_a");
        _mapUMLPolicySimple({
            name: "pol_b",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100,
            derivativesRevShare: 100
        });
        UMLPolicy memory polB = _getMappedUmlPolicy("pol_b");
        // We set some indifferents
        polA.attribution = true;
        polB.attribution = !polA.attribution;
        polA.transferable = true;
        polB.transferable = !polA.transferable;

        // Content restrictions (revert)
        polA.contentRestrictions = new string[](1);
        polA.contentRestrictions[0] = "adult";
        polB.contentRestrictions = new string[](1);
        polB.contentRestrictions[0] = "child";
        _testRevertCompat(polA, polB, UMLFrameworkErrors.UMLPolicyFrameworkManager__StringArrayMismatch.selector);
    }

    function _test_register_mint_AB(
        UMLPolicy memory polA,
        UMLPolicy memory polB
    ) internal returns (uint256 polAId, uint256 polBId) {
        // Mock set minRoyalty for IPAccount 1 and 2 for `mintLicense`s to succeed
        mockRoyaltyPolicyLS.setMinRoyalty(ipId1, polA.commercialRevShare);
        mockRoyaltyPolicyLS.setMinRoyalty(ipId2, polB.commercialRevShare);

        polAId = umlFramework.registerPolicy(polA);
        vm.prank(ipId1);
        licenses.push(licensingModule.mintLicense(polAId, ipId1, 1, alice));

        polBId = umlFramework.registerPolicy(polB);
        vm.prank(ipId2);
        licenses.push(licensingModule.mintLicense(polBId, ipId2, 2, alice));
    }

    function _testRevertCompat(UMLPolicy memory polA, UMLPolicy memory polB, bytes4 errorSelector) internal {
        _test_register_mint_AB(polA, polB);

        vm.expectRevert(errorSelector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, 0);
        licenses = new uint256[](0);
    }

    function _testSuccessCompat(UMLPolicy memory polA, UMLPolicy memory polB, uint256 expectedPolicies) internal {
        (uint256 polAId, uint256 polBId) = _test_register_mint_AB(polA, polB);

        vm.prank(alice);
        licensingModule.linkIpToParents(licenses, ipId4, 0);
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
