// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { UMLPolicy } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { TestHelper } from "test/foundry/utils/TestHelper.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { TokenGatedHook } from "contracts/modules/hooks/TokenGatedHook.sol";

contract UMLPolicyFrameworkTest is TestHelper {
    UMLPolicyFrameworkManager internal umlFramework;

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipOwner = vm.addr(1);
    address public licenseHolder = address(0x101);
    MockERC721 internal gatedNftFoo = new MockERC721("GatedNftFoo");

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
        UMLPolicy memory umlPolicy = UMLPolicy({
            transferable: true,
            attribution: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializers: emptyStringArray,
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
            commercializers: new address[](0),
            commercializersData : new bytes[](0),
            commercialRevShare: 0,
            derivativesAllowed: false, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: territories,
            distributionChannels: distributionChannels,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(mockRoyaltyPolicyLS)
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
            commercializers: new address[](0),
            commercializersData : new bytes[](0),
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
        TokenGatedHook tokenGatedHook = new TokenGatedHook();

        // commercialAttribution = true should revert
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddAttribution.selector);
        umlFramework.registerPolicy(umlPolicy);
        // Non empty commercializers should revert
        umlPolicy.commercialAttribution = false;
        umlPolicy.commercializers = new address[](1);
        umlPolicy.commercializers[0] = address(tokenGatedHook);
        umlPolicy.commercializersData = new bytes[](1);
        umlPolicy.commercializersData[0] = abi.encode(address(gatedNftFoo));
        vm.expectRevert(
            UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers.selector
        );
        umlFramework.registerPolicy(umlPolicy);
        // No rev share should be set; revert
        umlPolicy.commercializers = new address[](0);
        umlPolicy.commercializersData = new bytes[](0);
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
        address[] memory commercializers = new address[](2);
        commercializers[0] = address(0x123);
        commercializers[1] = address(0x456);
        bytes[] memory commercializersData = new bytes[](2);
        commercializersData[0] = abi.encode(address(0x987));
        commercializersData[1] = abi.encode(address(0x653));
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true,
            commercialAttribution: true,
            commercializers: commercializers,
            commercializersData: commercializersData,
            commercialRevShare: 123123,
            derivativesAllowed: true, // If false, derivativesRevShare should revert
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 1,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(mockRoyaltyPolicyLS)
        });
        uint256 policyId = umlFramework.registerPolicy(umlPolicy);
        UMLPolicy memory policy = umlFramework.getPolicy(policyId);
        assertEq(keccak256(abi.encode(policy)), keccak256(abi.encode(umlPolicy)));
    }

    function test_UMLPolicyFrameworkManager__derivatives_notAllowed_revert_settingIncompatibleTerms() public {
        // If no derivative values allowed
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: true, // So derivativesRevShare doesn't revert for this
            commercialAttribution: false,
            commercializers: new address[](0),
            commercializersData : new bytes[](0),
            commercialRevShare: 0,
            derivativesAllowed: false,
            derivativesAttribution: true,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(mockRoyaltyPolicyLS)
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
            commercializers: new address[](0),
            commercializersData : new bytes[](0),
            commercialRevShare: 0,
            derivativesAllowed: true, // If false, derivativesRevShare should revert
            derivativesAttribution: true,
            derivativesApproval: true,
            derivativesReciprocal: true,
            derivativesRevShare: 123,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(mockRoyaltyPolicyLS)
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
                commercializers: new address[](0),
                commercializersData : new bytes[](0),
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
        uint256 policyId = umlFramework.registerPolicy(
            UMLPolicy({
                transferable: false,
                attribution: false,
                commercialUse: false,
                commercialAttribution: false,
                commercializers: new address[](0),
                commercializersData : new bytes[](0),
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
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: true,
            commercialUse: false,
            commercialAttribution: false,
            commercializers: new address[](0),
            commercializersData : new bytes[](0),
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
        UMLPolicy memory umlPolicy = UMLPolicy({
            attribution: false,
            transferable: false,
            commercialUse: false,
            commercialAttribution: false,
            commercializers: new address[](0),
            commercializersData : new bytes[](0),
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

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
