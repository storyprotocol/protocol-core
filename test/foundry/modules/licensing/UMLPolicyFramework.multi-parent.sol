// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { IUMLPolicyFrameworkManager, UMLPolicy, UMLRights } from "contracts/interfaces/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

import "forge-std/console2.sol";

contract UMLPolicyFrameworkMultiParentTest is Test {
    MockAccessController internal accessController = new MockAccessController();
    IPAccountRegistry internal ipAccountRegistry;

    LicenseRegistry internal registry;

    UMLPolicyFrameworkManager internal umlFramework;

    MockERC721 nft = new MockERC721("MockERC721");

    string internal licenseUrl = "https://example.com/license";
    address internal bob = address(0x111);
    address internal ipId1;
    address internal ipId2;
    address internal ipId3;
    address internal alice = address(0x222);
    address internal ipId4;

    uint256[] internal licenses;

    string[] internal emptyStringArray = new string[](0);
    mapping(string => UMLPolicy) internal policies;
    mapping(string => uint256) internal policyIDs;

    modifier withPolicy(string memory name, bool commercial, bool derivatives, bool reciprocal) {
        _savePolicyInMapping(name, commercial, derivatives, reciprocal);
        policyIDs[name] = umlFramework.registerPolicy(policies[name]);
        _;
    }

    modifier withLicense(string memory policyName, address ipId, address owner) {
        uint256 licenseId = registry.mintLicense(policyIDs[policyName], ipId, 1, owner);
        licenses.push(licenseId);
        _;
    }

    function setUp() public {
        ipAccountRegistry = new IPAccountRegistry(
            address(new ERC6551Registry()),
            address(accessController),
            address(new IPAccountImpl())
        );
        registry = new LicenseRegistry(address(accessController), address(ipAccountRegistry));
        umlFramework = new UMLPolicyFrameworkManager(
            address(accessController),
            address(registry),
            "UMLPolicyFrameworkManager",
            licenseUrl
        );
        registry.registerPolicyFrameworkManager(address(umlFramework));

        nft.mintId(bob, 1);
        nft.mintId(bob, 2);
        nft.mintId(bob, 3);
        nft.mintId(alice, 4);

        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);
        ipId3 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 3);
        ipId4 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 4);

        vm.label(bob, "Bob");
        vm.label(alice, "Alice");
        vm.label(ipId1, "IP1");
        vm.label(ipId2, "IP2");
        vm.label(ipId3, "IP3");
        vm.label(ipId4, "IP4");
    }

    /// STARTING FROM AN ORIGINAL WORK
    function test_UMLPolicyFramework_multiParent_AliceSets3Parents_SamePolicyReciprocal()
        withPolicy("reciprocal", true, true, true)
        withLicense("reciprocal", ipId1, alice)
        withLicense("reciprocal", ipId2, alice)
        withLicense("reciprocal", ipId3, alice)
        public {
        vm.prank(alice);
        registry.linkIpToParents(licenses, ipId4, alice);
        assertEq(registry.totalParentsForIpId(ipId4), 3);
        address[] memory parents = registry.parentIpIds(ipId4);
        for (uint256 i = 0; i < licenses.length; i++) {
            Licensing.License memory license = registry.license(licenses[i]);
            assertEq(parents[i], license.licensorIpId);
        }
        assertEq(registry.totalPoliciesForIp(false, ipId4), 0);
        assertEq(registry.totalPoliciesForIp(true, ipId4), 1);
        assertTrue(registry.isPolicyIdSetForIp(true, ipId4, policyIDs["reciprocal"]));
    }

    function _savePolicyInMapping(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal
    ) internal {
        policies[name] = UMLPolicy({
            attribution: true,
            transferable: true,
            commercialUse: commercial,
            commercialAttribution: false,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: derivatives,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: reciprocal,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray
        });
    }

}
