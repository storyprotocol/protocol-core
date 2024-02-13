// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { UMLPolicy } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { MockTokenGatedHook } from "test/foundry/mocks/MockTokenGatedHook.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.sol";

contract UMLPolicyFrameworkTest is BaseTest {
    UMLPolicyFrameworkManager internal umlFramework;

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public licenseHolder = address(0x101);
    MockERC721 internal gatedNftFoo = new MockERC721("GatedNftFoo");
    MockTokenGatedHook internal tokenGatedHook = new MockTokenGatedHook();

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
        buildDeployPolicyCondition(
            DeployPolicyCondition({
                arbitrationPolicySP: false,
                royaltyPolicyLS: true // deploy to set address for commercial licenses
            })
        );
        deployConditionally();
        postDeploymentSetup();

        // Call `getXXX` here to either deploy mock or use real contracted deploy via the
        // deployConditionally() call above.
        // TODO: three options, auto/mock/real in deploy condition, so no need to call getXXX
        accessController = IAccessController(getAccessController());
        licensingModule = ILicensingModule(getLicensingModule());

        umlFramework = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "UMLPolicyFrameworkManager",
            licenseUrl
        );

        licensingModule.registerPolicyFrameworkManager(address(umlFramework));

        mockNFT.mintId(alice, 1);
        mockNFT.mintId(alice, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(mockNFT), 2);
    }

    function test_UMLPolicyFrameworkManager_getPolicyId() public {
        UMLPolicy memory umlPolicy = UMLPolicy({
            transferable: true,
            attribution: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(0)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        assertEq(umlFramework.getPolicyId(umlPolicy), policyId);
    }

    function test_UMLPolicyFrameworkManager__valuesSetCorrectly() public {
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
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: false, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: territories,
            distributionChannels: distributionChannels,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(royaltyPolicyLS)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    /////////////////////////////////////////////////////////////
    //////              COMMERCIAL USE TERMS               //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager__commercialUse_disallowed_revert_settingIncompatibleTerms() public {
        // If no commercial values allowed
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: false,
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(0) // must be 0 because commercialUse = false
        });

        gatedNftFoo.mintId(address(this), 1);

        // commercialAttribution = true should revert
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddAttribution.selector);
        umlFramework.registerPolicy(umlPolicy);
        // Non empty commercializers should revert
        umlPolicy.commercialAttribution = false;
        umlPolicy.commercializerChecker = address(tokenGatedHook);
        umlPolicy.commercializerCheckerData = abi.encode(address(gatedNftFoo));
        vm.expectRevert(
            UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers.selector
        );
        umlFramework.registerPolicy(umlPolicy);
        // No rev share should be set; revert
        umlPolicy.commercializerChecker = address(0);
        umlPolicy.commercializerCheckerData = "";
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
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: address(tokenGatedHook),
            commercializerCheckerData: abi.encode(address(gatedNftFoo)),
            commercialRevShare: 123123,
            derivativesAllowed: true, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 1,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(royaltyPolicyLS)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    function test_UMLPolicyFrameworkManager__commercialUse_InvalidCommericalizer() public {
        address invalidCommercializerChecker = address(0x123);
        bytes memory invalideCommercializerCheckerData = abi.encode(address(0x456));
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true,
            commercialAttribution: true,
            commercializerChecker: invalidCommercializerChecker,
            commercializerCheckerData: abi.encode(address(gatedNftFoo)),
            commercialRevShare: 123123,
            derivativesAllowed: true, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 1,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(royaltyPolicyLS)
        });
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.PolicyFrameworkManager__CommercializerCheckerDoesNotSupportHook.selector,
                invalidCommercializerChecker
            )
        );
        umlFramework.registerPolicy(umlPolicy);

        umlPolicy.commercializerChecker = address(tokenGatedHook);
        umlPolicy.commercializerCheckerData = invalideCommercializerCheckerData;
        vm.expectRevert("MockTokenGatedHook: Invalid token address");
        umlFramework.registerPolicy(umlPolicy);
    }

    function test_UMLPolicyFrameworkManager__derivatives_notAllowed_revert_settingIncompatibleTerms() public {
        // If no derivative values allowed
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true, // So derivativesRevShare doesn't revert for this
            commercialAttribution: false,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(royaltyPolicyLS)
        });
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
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true, // If false, derivativesRevShare should revert
            commercialAttribution: true,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: true, // If false, derivativesRevShare should revert
            derivativesAttribution: true,
            derivativesApproval: true,
            derivativesReciprocal: true,
            derivativesRevShare: 123,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(royaltyPolicyLS)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    /////////////////////////////////////////////////////////////
    //////                  APPROVAL TERMS                 //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager_derivatives_withApproval_revert_linkNotApproved() public {
        uint256 policyId = umlFramework.registerPolicy(
            UMLPolicy({
                transferable: false,
                attribution: false,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: true,
                derivativesReciprocal: false,
                derivativesRevShare: 0,
                territories: emptyStringArray,
                distributionChannels: emptyStringArray,
                contentRestrictions: emptyStringArray,
                royaltyPolicy: address(0) // must be 0 because commercialUse = false
            })
        );

        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, alice);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.prank(licenseRegistry.licensorIpId(licenseId));
        umlFramework.setApproval(licenseId, ipId2, false);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.expectRevert(Errors.LicensingModule__LinkParentParamFailed.selector);
        vm.prank(alice);
        licensingModule.linkIpToParents(licenseIds, ipId2, 0);
    }

    function test_UMLPolicyFrameworkManager__derivatives_withApproval_linkApprovedIpId() public {
        uint256 policyId = umlFramework.registerPolicy(
            UMLPolicy({
                transferable: false,
                attribution: false,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: true,
                derivativesReciprocal: false,
                derivativesRevShare: 0,
                territories: emptyStringArray,
                distributionChannels: emptyStringArray,
                contentRestrictions: emptyStringArray,
                royaltyPolicy: address(0) // must be 0 because commercialUse = false
            })
        );

        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, alice);
        assertFalse(umlFramework.isDerivativeApproved(licenseId, ipId2));

        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        vm.prank(alice);
        licenseRegistry.safeTransferFrom(alice, licenseHolder, licenseId, 1, "");

        vm.prank(licenseRegistry.licensorIpId(licenseId));
        umlFramework.setApproval(licenseId, ipId2, true);
        assertTrue(umlFramework.isDerivativeApproved(licenseId, ipId2));

        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.prank(alice);
        licensingModule.linkIpToParents(licenseIds, ipId2, 0);
        assertTrue(licensingModule.isParent(ipId1, ipId2));
    }

    /////////////////////////////////////////////////////////////
    //////                  TRANSFER TERMS                 //////
    /////////////////////////////////////////////////////////////

    function test_UMLPolicyFrameworkManager__transferrable() public {
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: false, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(0) // must be 0 because commercialUse = false
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        vm.prank(alice);
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
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: false,
            commercialAttribution: false,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 0,
            derivativesAllowed: false, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(0) // must be 0 because commercialUse = false
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        vm.prank(alice);
        licensingModule.addPolicyToIp(ipId1, policyId);
        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1);
        address licenseHolder2 = address(0x222);
        vm.startPrank(licenseHolder);
        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        vm.stopPrank();
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
