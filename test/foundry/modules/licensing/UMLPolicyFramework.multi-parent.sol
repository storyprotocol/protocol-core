// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { IUMLPolicyFrameworkManager, UMLPolicy, UMLInheritedPolicyAggregator } from "contracts/interfaces/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { TestHelper } from "test/utils/TestHelper.sol";

import "forge-std/console2.sol";

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

    modifier withUMLPolicySimple(string memory name, bool commercial, bool derivatives, bool reciprocal) {
        _mapUMLPolicySimple(name, commercial, derivatives, reciprocal);
        _addUMLPolicyFromMapping(name, address(umlFramework));
        _;
    }

    modifier withLicense(string memory policyName, address ipId, address owner) {
        uint256 policyId = _getUmlPolicyId(policyName);
        vm.prank(ipIdToOwner[ipId]);
        uint256 licenseId = licenseRegistry.mintLicense(policyId, ipId, 1, owner);
        licenses.push(licenseId);
        _;
    }

    function setUp() public override {
        TestHelper.setUp();
        nft = erc721.ape;

        umlFramework = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licenseRegistry),
            address(royaltyModule),
            "UMLPolicyFrameworkManager",
            licenseUrl
        );

        licenseRegistry.registerPolicyFrameworkManager(address(umlFramework));

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
        withUMLPolicySimple("reciprocal", true, true, true)
        withLicense("reciprocal", ipId1, alice)
        withLicense("reciprocal", ipId2, alice)
        withLicense("reciprocal", ipId3, alice)
        public {
        vm.prank(alice);
        licenseRegistry.linkIpToParents(licenses, ipId4, alice);
        assertEq(licenseRegistry.totalParentsForIpId(ipId4), 3);
        address[] memory parents = licenseRegistry.parentIpIds(ipId4);
        for (uint256 i = 0; i < licenses.length; i++) {
            Licensing.License memory license = licenseRegistry.license(licenses[i]);
            assertEq(parents[i], license.licensorIpId);
        }
        assertEq(licenseRegistry.totalPoliciesForIp(false, ipId4), 0);
        assertEq(licenseRegistry.totalPoliciesForIp(true, ipId4), 1);
        assertTrue(licenseRegistry.isPolicyIdSetForIp(true, ipId4, _getUmlPolicyId("reciprocal")));
    }

    function test_UMLPolicyFramework_multiParent_revert_AliceSets3Parents_OneNonReciprocal()
        withUMLPolicySimple("reciprocal", true, true, true)
        withUMLPolicySimple("non_reciprocal", true, true, false)
        withLicense("reciprocal", ipId1, alice)
        withLicense("non_reciprocal", ipId2, alice)
        withLicense("reciprocal", ipId3, alice)
        public {
        vm.expectRevert(
            UMLFrameworkErrors.UMLPolicyFrameworkManager__ReciprocalValueMismatch.selector
        );
        vm.prank(alice);
        licenseRegistry.linkIpToParents(licenses, ipId4, alice);
    }

    function test_UMLPolicyFramework_multiParent_revert_AliceSets3Parents_3ReciprocalButDifferent()
        withUMLPolicySimple("reciprocal", true, true, true)
        withLicense("reciprocal", ipId1, alice)
        withLicense("reciprocal", ipId2, alice)
        public {
        // Save a new policy (change some value to change the policyId)
        _mapUMLPolicySimple("other", true, true, true);
        _getMappedUmlPolicy("other").attribution = !_getMappedUmlPolicy("other").attribution;
        _addUMLPolicyFromMapping("other", address(umlFramework));
        vm.prank(ipId3);
        licenses.push(licenseRegistry.mintLicense(_getUmlPolicyId("other"), ipId3, 1, alice));
        vm.expectRevert(
            UMLFrameworkErrors.UMLPolicyFrameworkManager__ReciprocalButDifferentPolicyIds.selector
        );
        vm.prank(alice);
        licenseRegistry.linkIpToParents(licenses, ipId4, alice);
    }

}
