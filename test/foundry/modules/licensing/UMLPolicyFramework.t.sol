// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { IUMLPolicyFrameworkManager, UMLPolicy } from "contracts/interfaces/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

import "forge-std/console2.sol";

contract UMLPolicyFrameworkTest is Test {
    MockAccessController public accessController = new MockAccessController();
    IPAccountRegistry public ipAccountRegistry;

    LicenseRegistry public registry;

    UMLPolicyFrameworkManager public umlFramework;

    MockERC721 nft = new MockERC721("MockERC721");

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipOwner = vm.addr(1);
    address public licenseHolder = address(0x101);
    string[] public emptyStringArray = new string[](0);

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
            address(0), // TODO: mock royaltyModule
            "UMLPolicyFrameworkManager",
            licenseUrl
        );
        registry.registerPolicyFrameworkManager(address(umlFramework));

        nft.mintId(ipOwner, 1);
        nft.mintId(ipOwner, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);
    }

    function test_UMLPolicyFrameworkManager_valuesSetCorrectly() public {
        string[] memory territories = new string[](2);
        territories[0] = "test1";
        territories[1] = "test2";
        string[] memory distributionChannels = new string[](1);
        distributionChannels[0] = "test3";
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: true,
            transferable: false,
            commercialUse: true,
            commercialAttribution: true,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: false, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: territories,
            distributionChannels: distributionChannels,
            royaltyPolicy: address(0xbeef)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    // COMMERCIAL USE TERMS

    function test_UMLPolicyFrameworkManager_commercialUse_disallowed_revert_settingIncompatibleTerms() public {
        // If no commercial values allowed
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: false,
            commercialAttribution: true,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            royaltyPolicy: address(0)
        });
        // commercialAttribution = true should revert
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddAttribution.selector);
        umlFramework.registerPolicy(umlPolicy);
        // Non empty commercializers should revert
        umlPolicy.commercialAttribution = false;
        umlPolicy.commercializers = new string[](1);
        umlPolicy.commercializers[0] = "test";
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddCommercializers.selector);
        umlFramework.registerPolicy(umlPolicy);
        // No rev share should be set; revert
        umlPolicy.commercializers = new string[](0);
        umlPolicy.commercialRevShare = 1;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddRevShare.selector);
        umlFramework.registerPolicy(umlPolicy);
        // No rev share should be set for derivatives either; revert
        umlPolicy.commercialRevShare = 0;
        umlPolicy.derivativesRevShare = 1;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddDerivRevShare.selector);
        umlFramework.registerPolicy(umlPolicy);
    }

    function test_UMLPolicyFrameworkManager_commercialUse_valuesSetCorrectly() public {
        string[] memory commercializers = new string[](2);
        commercializers[0] = "test1";
        commercializers[1] = "test2";
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true,
            commercialAttribution: true,
            commercializers: commercializers,
            commercialRevShare: 123123,
            derivativesAllowed: true, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 1,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            royaltyPolicy: address(0xbeef)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    function test_UMLPolicyFrameworkManager_commercialUse_revenueShareSetOnLinking() public {
        // TODO
    }

    // DERIVATIVE TERMS
    function test_UMLPolicyFrameworkManager_derivatives_notAllowed_revert_creating2ndDerivative() public {}

    function test_UMLPolicyFrameworkManager_derivatives_notAllowed_revert_settingIncompatibleTerms() public {
        // If no derivative values allowed
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true, // So derivativesRevShare doesn't revert for this
            commercialAttribution: false,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            royaltyPolicy: address(0xbeef)
        });
        // derivativesAttribution = true should revert
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddAttribution.selector);
        umlFramework.registerPolicy(umlPolicy);
        // Requesting approval for derivatives should revert
        umlPolicy.derivativesAttribution = false;
        umlPolicy.derivativesApproval = true;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddApproval.selector);
        umlFramework.registerPolicy(umlPolicy);
        // Setting reciprocal license should revert
        umlPolicy.derivativesApproval = false;
        umlPolicy.derivativesReciprocal = true;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddReciprocal.selector);
        umlFramework.registerPolicy(umlPolicy);
        // No rev share should be set for derivatives either; revert
        umlPolicy.derivativesReciprocal = false;
        umlPolicy.derivativesRevShare = 1;
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddRevShare.selector);
        umlFramework.registerPolicy(umlPolicy);
    }

    function test_UMLPolicyFrameworkManager_derivatives_valuesSetCorrectly() public {
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true, // If false, derivativesRevShare should revert
            commercialAttribution: true,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: true, // If false, derivativesRevShare should revert
            derivativesAttribution: true,
            derivativesApproval: true,
            derivativesReciprocal: true,
            derivativesRevShare: 123,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            royaltyPolicy: address(0xbeef)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    function test_UMLPolicyFrameworkManager_derivatives_setRevenueShareWhenLinking2ndDerivative() public {
        // TODO
    }

    // APPROVAL TERMS

    function test_UMLPolicyFrameworkManager_derivativesWithApproval_revert_linkNotApproved() public {
        uint256 policyId = umlFramework.registerPolicy(
            UMLPolicy({
                attribution: false,
                transferable: false,
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
                distributionChannels: emptyStringArray,
                royaltyPolicy: address(0)
            })
        );
        console2.log("policyId", policyId);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));
        vm.prank(ipOwner);
        umlFramework.setApproval(licenseId, ipId2, false);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.expectRevert(Errors.LicenseRegistry__LinkParentParamFailed.selector);
        vm.prank(ipOwner);
        registry.linkIpToParent(licenseId, ipId2, licenseHolder);
    }

    function test_UMLPolicyFrameworkManager_derivatives_withApproval_linkApprovedIpId() public {
        uint256 policyId = umlFramework.registerPolicy(
            UMLPolicy({
                attribution: false,
                transferable: false,
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
                distributionChannels: emptyStringArray,
                royaltyPolicy: address(0)
            })
        );
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);

        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));
        vm.prank(ipOwner);
        umlFramework.setApproval(licenseId, ipId2, true);
        assertTrue(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.prank(ipOwner);
        registry.linkIpToParent(licenseId, ipId2, licenseHolder);
        assertTrue(registry.isParent(ipId1, ipId2));
    }

    function test_UMLPolicyFrameworkManager_derivatives_withApproval_revert_approverNotLicensor() public {
        // TODO: ACL
    }

    // TRANSFER TERMS

    function test_UMLPolicyFrameworkManager_transferrable() public {
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: false, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            royaltyPolicy: address(0)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.prank(licenseHolder);
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(registry.balanceOf(licenseHolder, licenseId), 0);
        assertEq(registry.balanceOf(licenseHolder2, licenseId), 1);
    }

    function test_UMLPolicyFrameworkManager_nonTransferrable_revertIfTransferExceptFromLicensor() public {
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: false,
            commercialAttribution: false,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: false, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            royaltyPolicy: address(0)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.startPrank(licenseHolder);
        vm.expectRevert(Errors.LicenseRegistry__TransferParamFailed.selector);
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        vm.stopPrank();
    }

    function test_UMLPolicyFrameworkManager_mintFee() public {
        // TODO
    }

    function test_tokenUri() public {
        // TODO
    }
}
