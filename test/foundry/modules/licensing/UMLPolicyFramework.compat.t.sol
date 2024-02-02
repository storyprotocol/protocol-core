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

contract UMLPolicyFrameworkCompatibilityTest is Test {
    MockAccessController internal accessController = new MockAccessController();
    IPAccountRegistry internal ipAccountRegistry;

    LicenseRegistry internal registry;

    UMLPolicyFrameworkManager internal umlFramework;

    MockERC721 nft = new MockERC721("MockERC721");

    string internal licenseUrl = "https://example.com/license";
    address internal bob = address(0x111);
    address internal ipId1;
    address internal alice = address(0x222);
    address internal ipId2;
    address internal don = address(0x333);
    address internal licenseHolder = address(0x101);
    string[] internal emptyStringArray = new string[](0);
    uint256 internal policyID;
    mapping(string => UMLPolicy) internal policies;
    mapping(string => uint256) internal policyIDs;

    modifier withPolicy(string memory name, bool commercial, bool derivatives, bool reciprocal) {
        _savePolicyInMapping(name, commercial, derivatives, reciprocal);
        policyIDs[name] = umlFramework.registerPolicy(policies[name]);
        _;
    }

    modifier withAliceOwningDerivativeIp2(string memory policyName) {
        vm.prank(bob);
        uint256 licenseId = registry.mintLicense(policyIDs[policyName], ipId1, 1, alice);
        vm.prank(alice);
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;
        console2.log("withAliceOwningDerivativeIp2");
        registry.linkIpToParents(licenseIds, ipId2, alice);
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
        nft.mintId(alice, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);
        vm.label(bob, "Bob");
        vm.label(alice, "Alice");
        vm.label(don, "Don");
        vm.label(ipId1, "IP1");
        vm.label(ipId2, "IP2");

    }

    /// STARTING FROM AN ORIGINAL WORK
    function test_UMLPolicyFramework_originalWork_bobAddsDifferentPoliciesAndAliceMints()
        withPolicy("comm_deriv", true, true, false)
        withPolicy("comm_non_deriv", true, false, false)
        public {
        // Bob can add different policies on IP1 without compatibility checks.
        vm.startPrank(bob);
        registry.addPolicyToIp(ipId1, policyIDs["comm_deriv"]);
        registry.addPolicyToIp(ipId1, policyIDs["comm_non_deriv"]);
        vm.stopPrank();
        bool isInherited = false;
        assertEq(registry.totalPoliciesForIp(isInherited, ipId1), 2);
        assertTrue(registry.isPolicyIdSetForIp(isInherited, ipId1, policyIDs["comm_deriv"]), "comm_deriv not set");
        assertTrue(registry.isPolicyIdSetForIp(isInherited, ipId1, policyIDs["comm_non_deriv"]), "comm_non_deriv not set");

        // Others can mint licenses to make derivatives of IP1 from each different policy,
        // as long as they pass the verifications
        uint256 licenseId1 = registry.mintLicense(policyIDs["comm_deriv"], ipId1, 1, don);
        assertEq(registry.balanceOf(don, licenseId1), 1, "Don doesn't have license1");
        
        uint256 licenseId2 = registry.mintLicense(policyIDs["comm_non_deriv"], ipId1, 1, don);
        assertEq(registry.balanceOf(don, licenseId2), 1, "Don doesn't have license2");
    }

    /// TODO: STARTING FROM AN ORIGINAL WORK, WITH APPROVALS and UPFRONT PAY


    function test_UMLPolicyFramework_originalWork_bobMintsWithDifferentPolicies()
        withPolicy("comm_deriv", true, true, false)
        withPolicy("comm_non_deriv", true, false, false)
        public {
        // Bob can add different policies on IP1 without compatibility checks.
        vm.startPrank(bob);
        uint256 licenseId1 = registry.mintLicense(policyIDs["comm_deriv"], ipId1, 1, don);
        assertEq(registry.balanceOf(don, licenseId1), 1, "Don doesn't have license1");
        
        uint256 licenseId2 = registry.mintLicense(policyIDs["comm_non_deriv"], ipId1, 1, don);
        assertEq(registry.balanceOf(don, licenseId2), 1, "Don doesn't have license2");
        vm.stopPrank();
    }

    
    function test_UMLPolicyFramework_originalWork_bobSetsPoliciesThenCompatibleParent()
        withPolicy("comm_deriv", true, true, false)
        withPolicy("comm_non_deriv", true, false, false)
        public {
        // TODO: This works if all policies compatible.
        // Can bob disable some policies?
    }


    // STARTING FROM DERIVATIVE WORK
    function test_UMLPolicyFramework_derivative_revert_cantMintDerivativeOfDerivative()
        withPolicy("comm_non_deriv", true, false, false)
        withAliceOwningDerivativeIp2("comm_non_deriv")
        public {
        vm.expectRevert(Errors.LicenseRegistry__MintLicenseParamFailed.selector);
        vm.prank(don);
        registry.mintLicense(policyIDs["comm_non_deriv"], ipId2, 1, don);
        vm.expectRevert(Errors.LicenseRegistry__MintLicenseParamFailed.selector);
        vm.prank(alice);
        registry.mintLicense(policyIDs["comm_non_deriv"], ipId2, 1, alice);
    }

    function test_UMLPolicyFramework_derivative_revert_AliceCantSetPolicyOnDerivativeOfDerivative()
        withPolicy("comm_non_deriv", true, false, false)
        withPolicy("comm_deriv", true, true, false)
        withAliceOwningDerivativeIp2("comm_non_deriv")
        public {
        
        vm.expectRevert(
            Errors.LicenseRegistry__DerivativesCannotAddPolicy.selector
        );
        vm.prank(alice);
        registry.addPolicyToIp(ipId2, policyIDs["comm_deriv"]);

        _savePolicyInMapping("other_policy", true, true, false);
        policies["other_policy"].attribution = false;
        policyIDs["other_policy"] = umlFramework.registerPolicy(policies["other_policy"]);

        vm.expectRevert(
            Errors.LicenseRegistry__DerivativesCannotAddPolicy.selector
        );
        vm.prank(alice);
        registry.addPolicyToIp(ipId2, policyIDs["other_policy"]);
    }

    // Reciprocal

    function test_UMLPolicyFramework_reciprocal_DonMintsLicenseFromIp2()
        withPolicy("comm_reciprocal", true, true, true)
        withAliceOwningDerivativeIp2("comm_reciprocal")
        public {
        vm.prank(don);
        uint256 licenseId = registry.mintLicense(policyIDs["comm_reciprocal"], ipId2, 1, don);
        assertEq(registry.balanceOf(don, licenseId), 1, "Don doesn't have license");

    }

    function test_UMLPolicyFramework_reciprocal_AliceMintsLicenseForP1inIP2()
        withPolicy("comm_reciprocal", true, true, true)
        withAliceOwningDerivativeIp2("comm_reciprocal")
        public {
        vm.prank(alice);
        uint256 licenseId = registry.mintLicense(policyIDs["comm_reciprocal"], ipId2, 1, alice);
        assertEq(registry.balanceOf(alice, licenseId), 1, "Alice doesn't have license");
    }

    function test_UMLPolicyFramework_reciprocal_revert_AliceTriesToSetPolicyInReciprocalDeriv()
        withPolicy("comm_reciprocal", true, true, true)
        withPolicy("other_policy", true, true, false)
        withAliceOwningDerivativeIp2("comm_reciprocal")
        public {
        vm.expectRevert(
            Errors.LicenseRegistry__DerivativesCannotAddPolicy.selector
        );
        vm.prank(alice);
        registry.addPolicyToIp(ipId2, policyIDs["other_policy"]);
        vm.expectRevert(
            Errors.LicenseRegistry__DerivativesCannotAddPolicy.selector
        );
        vm.prank(alice);
        registry.addPolicyToIp(ipId2, policyIDs["comm_reciprocal"]);
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
