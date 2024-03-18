// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import { RoyaltyPolicyLAP } from "../../../../contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { ILiquidSplitMain } from "../../../../contracts/interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

import { BaseTest } from "../../utils/BaseTest.t.sol";

contract TestRoyaltyPolicyLAP is BaseTest {
    event PolicyInitialized(
        address ipId,
        address splitClone,
        address claimer,
        uint32 royaltyStack,
        address[] targetAncestors,
        uint32[] targetRoyaltyAmount
    );

    RoyaltyPolicyLAP internal testRoyaltyPolicyLAP;

    address[] internal MAX_ANCESTORS_ = new address[](14);
    uint32[] internal MAX_ANCESTORS_ROYALTY_ = new uint32[](14);
    address[] internal parentsIpIds100;

    function setUp() public override {
        super.setUp();
        buildDeployModuleCondition(
            DeployModuleCondition({ disputeModule: false, royaltyModule: true, licensingModule: false })
        );
        buildDeployPolicyCondition(DeployPolicyCondition({ arbitrationPolicySP: false, royaltyPolicyLAP: true }));
        deployConditionally();
        postDeploymentSetup();

        vm.startPrank(u.admin);
        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        _setupMaxUniqueTree();
    }

    function _setupMaxUniqueTree() internal {
        // init royalty policy for roots
        royaltyPolicyLAP.onLicenseMinting(address(7), abi.encode(uint32(7)), "");
        royaltyPolicyLAP.onLicenseMinting(address(8), abi.encode(uint32(8)), "");
        royaltyPolicyLAP.onLicenseMinting(address(9), abi.encode(uint32(9)), "");
        royaltyPolicyLAP.onLicenseMinting(address(10), abi.encode(uint32(10)), "");
        royaltyPolicyLAP.onLicenseMinting(address(11), abi.encode(uint32(11)), "");
        royaltyPolicyLAP.onLicenseMinting(address(12), abi.encode(uint32(12)), "");
        royaltyPolicyLAP.onLicenseMinting(address(13), abi.encode(uint32(13)), "");
        royaltyPolicyLAP.onLicenseMinting(address(14), abi.encode(uint32(14)), "");

        // init 2nd level with children
        address[] memory parents = new address[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);
        bytes[] memory encodedLicenseData = new bytes[](2);

        // 3 is child of 7 and 8
        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties1[0] = 7;
        parentRoyalties1[1] = 8;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(3), parents, encodedLicenseData, "");

        // 4 is child of 9 and 10
        parents[0] = address(9);
        parents[1] = address(10);
        parentRoyalties1[0] = 9;
        parentRoyalties1[1] = 10;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(4), parents, encodedLicenseData, "");

        // 5 is child of 11 and 12
        parents[0] = address(11);
        parents[1] = address(12);
        parentRoyalties1[0] = 11;
        parentRoyalties1[1] = 12;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(5), parents, encodedLicenseData, "");

        // 6 is child of 13 and 14
        parents[0] = address(13);
        parents[1] = address(14);
        parentRoyalties1[0] = 13;
        parentRoyalties1[1] = 14;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(6), parents, encodedLicenseData, "");

        // init 3rd level with children
        // 1 is child of 3 and 4
        parents[0] = address(3);
        parents[1] = address(4);
        parentRoyalties1[0] = 3;
        parentRoyalties1[1] = 4;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(1), parents, encodedLicenseData, "");

        // 2 is child of 5 and 6
        parents[0] = address(5);
        parents[1] = address(6);
        parentRoyalties1[0] = 5;
        parentRoyalties1[1] = 6;

        for (uint32 i = 0; i < parentRoyalties1.length; i++) {
            encodedLicenseData[i] = abi.encode(parentRoyalties1[i]);
        }
        royaltyPolicyLAP.onLinkToParents(address(2), parents, encodedLicenseData, "");

        // ancestors of parent 1
        MAX_ANCESTORS_[0] = address(1);
        MAX_ANCESTORS_[1] = address(3);
        MAX_ANCESTORS_[2] = address(7);
        MAX_ANCESTORS_[3] = address(8);
        MAX_ANCESTORS_[4] = address(4);
        MAX_ANCESTORS_[5] = address(9);
        MAX_ANCESTORS_[6] = address(10);
        // ancestors of parent 2
        MAX_ANCESTORS_[7] = address(2);
        MAX_ANCESTORS_[8] = address(5);
        MAX_ANCESTORS_[9] = address(11);
        MAX_ANCESTORS_[10] = address(12);
        MAX_ANCESTORS_[11] = address(6);
        MAX_ANCESTORS_[12] = address(13);
        MAX_ANCESTORS_[13] = address(14);

        MAX_ANCESTORS_ROYALTY_[0] = 1;
        MAX_ANCESTORS_ROYALTY_[1] = 3;
        MAX_ANCESTORS_ROYALTY_[2] = 7;
        MAX_ANCESTORS_ROYALTY_[3] = 8;
        MAX_ANCESTORS_ROYALTY_[4] = 4;
        MAX_ANCESTORS_ROYALTY_[5] = 9;
        MAX_ANCESTORS_ROYALTY_[6] = 10;
        MAX_ANCESTORS_ROYALTY_[7] = 2;
        MAX_ANCESTORS_ROYALTY_[8] = 5;
        MAX_ANCESTORS_ROYALTY_[9] = 11;
        MAX_ANCESTORS_ROYALTY_[10] = 12;
        MAX_ANCESTORS_ROYALTY_[11] = 6;
        MAX_ANCESTORS_ROYALTY_[12] = 13;
        MAX_ANCESTORS_ROYALTY_[13] = 14;

        parentsIpIds100 = new address[](2);
        parentsIpIds100[0] = address(1);
        parentsIpIds100[1] = address(2);
    }

    function test_RoyaltyPolicyLAP_setAncestorsVaultImplementation_ZeroAncestorsVaultImpl() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroAncestorsVaultImpl.selector);
        royaltyPolicyLAP.setAncestorsVaultImplementation(address(0));
    }

    function test_RoyaltyPolicyLAP_setAncestorsVaultImplementation_ImplementationAlreadySet() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ImplementationAlreadySet.selector);
        royaltyPolicyLAP.setAncestorsVaultImplementation(address(2));
    }

    function test_RoyaltyPolicyLAP_setAncestorsVaultImplementation() public {
        RoyaltyPolicyLAP royaltyPolicyLAP2 = new RoyaltyPolicyLAP(
            address(1),
            address(2),
            address(3),
            address(4),
            address(governance)
        );

        vm.startPrank(u.admin);
        royaltyPolicyLAP2.setAncestorsVaultImplementation(address(2));

        assertEq(royaltyPolicyLAP2.ANCESTORS_VAULT_IMPL(), address(2));
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_NotRoyaltyModule() public {
        vm.stopPrank();
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLicenseMinting(address(1), abi.encode(uint32(0)), abi.encode(uint32(0)));
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_AboveRoyaltyStackLimit() public {
        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit.selector);
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(1001)), "");
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting_revert_LastPositionNotAbleToMintLicense() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }

        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, "");

        vm.expectRevert(Errors.RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense.selector);
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(0)), "");
    }

    function test_RoyaltyPolicyLAP_onLicenseMinting() public {
        royaltyPolicyLAP.onLicenseMinting(address(100), abi.encode(uint32(0)), "");

        (
            ,
            address splitClone,
            address ancestorsVault,
            uint32 royaltyStack,
            address[] memory ancestors,
            uint32[] memory ancestorsRoyalties
        ) = royaltyPolicyLAP.getRoyaltyData(address(100));

        assertEq(royaltyStack, 0);
        assertEq(ancestors.length, 0);
        assertEq(ancestorsRoyalties.length, 0);
        assertFalse(splitClone == address(0));
        assertEq(ancestorsVault, address(0));
    }

    function test_RoyaltyPolicyLAP_onLinkToParents_revert_NotRoyaltyModule() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }

        vm.stopPrank();
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, "");
    }

    function test_RoyaltyPolicyLAP_onLinkToParents_revert_AboveParentLimit() public {
        bytes[] memory encodedLicenseData = new bytes[](3);
        for (uint32 i = 0; i < 3; i++) {
            encodedLicenseData[i] = abi.encode(1);
        }

        address[] memory excessParents = new address[](3);
        excessParents[0] = address(1);
        excessParents[1] = address(2);
        excessParents[2] = address(3);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveParentLimit.selector);
        royaltyPolicyLAP.onLinkToParents(address(100), excessParents, encodedLicenseData, "");
    }

    function test_RoyaltyPolicyLAP_onLinkToParents() public {
        bytes[] memory encodedLicenseData = new bytes[](2);
        for (uint32 i = 0; i < parentsIpIds100.length; i++) {
            encodedLicenseData[i] = abi.encode(parentsIpIds100[i]);
        }

        royaltyPolicyLAP.onLinkToParents(address(100), parentsIpIds100, encodedLicenseData, "");

        (
            ,
            address splitClone,
            address ancestorsVault,
            uint32 royaltyStack,
            address[] memory ancestors,
            uint32[] memory ancestorsRoyalties
        ) = royaltyPolicyLAP.getRoyaltyData(address(100));

        assertEq(royaltyStack, 105);
        for (uint32 i = 0; i < ancestorsRoyalties.length; i++) {
            assertEq(ancestorsRoyalties[i], MAX_ANCESTORS_ROYALTY_[i]);
        }
        assertEq(ancestors, MAX_ANCESTORS_);
        assertFalse(splitClone == address(0));
        assertFalse(ancestorsVault == address(0));
    }

    function test_RoyaltyPolicyLAP_onRoyaltyPayment_NotRoyaltyModule() public {
        vm.stopPrank();
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onRoyaltyPayment(address(1), address(1), address(1), 0);
    }

    function test_RoyaltyPolicyLAP_onRoyaltyPayment() public {
        (, address splitClone2, , , , ) = royaltyPolicyLAP.getRoyaltyData(address(2));
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(address(1), royaltyAmount);
        vm.stopPrank();

        vm.startPrank(address(1));
        USDC.approve(address(royaltyPolicyLAP), royaltyAmount);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));

        uint256 splitClone2USDCBalBefore = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalBefore = USDC.balanceOf(address(1));

        royaltyPolicyLAP.onRoyaltyPayment(address(1), address(2), address(USDC), royaltyAmount);

        uint256 splitClone2USDCBalAfter = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalAfter = USDC.balanceOf(address(1));

        assertEq(splitClone2USDCBalAfter - splitClone2USDCBalBefore, royaltyAmount);
        assertEq(splitMainUSDCBalBefore - splitMainUSDCBalAfter, royaltyAmount);
    }

    function test_RoyaltyPolicyLAP_distributeIpPoolFunds() public {
        (, address splitClone2, address ancestorsVault2, , , ) = royaltyPolicyLAP.getRoyaltyData(address(2));

        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        accounts[0] = address(2);
        accounts[1] = ancestorsVault2;

        uint256 splitClone2USDCBalBefore = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalBefore = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());

        royaltyPolicyLAP.distributeIpPoolFunds(address(2), address(USDC), accounts, address(0));

        uint256 splitClone2USDCBalAfter = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalAfter = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());

        assertApproxEqRel(splitClone2USDCBalBefore - splitClone2USDCBalAfter, royaltyAmount, 0.0001e18);
        assertApproxEqRel(splitMainUSDCBalAfter - splitMainUSDCBalBefore, royaltyAmount, 0.0001e18);
    }

    function test_RoyaltyPolicyLAP_claimFromIpPool() public {
        (, address splitClone2, address ancestorsVault2, , , ) = royaltyPolicyLAP.getRoyaltyData(address(2));

        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        accounts[0] = address(2);
        accounts[1] = ancestorsVault2;

        royaltyPolicyLAP.distributeIpPoolFunds(address(2), address(USDC), accounts, address(0));

        uint256 expectedAmountToBeClaimed = ILiquidSplitMain(royaltyPolicyLAP.LIQUID_SPLIT_MAIN()).getERC20Balance(
            address(2),
            USDC
        );

        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = USDC;

        uint256 splitMainUSDCBalBefore = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());
        uint256 address2USDCBalBefore = USDC.balanceOf(address(2));

        royaltyPolicyLAP.claimFromIpPool(address(2), tokens);

        uint256 splitMainUSDCBalAfter = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());
        uint256 address2USDCBalAfter = USDC.balanceOf(address(2));

        assertApproxEqRel(splitMainUSDCBalBefore - splitMainUSDCBalAfter, expectedAmountToBeClaimed, 0.0001e18);
        assertApproxEqRel(address2USDCBalAfter - address2USDCBalBefore, expectedAmountToBeClaimed, 0.0001e18);
    }

    function test_RoyaltyPolicyLAP_claimAsFullRnftOwner() public {
        (, address splitClone7, , , , ) = royaltyPolicyLAP.getRoyaltyData(address(7));

        uint256 royaltyAmountUSDC = 100 * 10 ** 6;
        USDC.mint(address(splitClone7), royaltyAmountUSDC);

        vm.startPrank(address(7));
        ERC1155(address(splitClone7)).setApprovalForAll(address(royaltyPolicyLAP), true);

        uint256 usdcClaimerBalBefore = USDC.balanceOf(address(7));
        uint256 rnftClaimerBalBefore = ERC1155(address(splitClone7)).balanceOf(address(7), 0);

        royaltyPolicyLAP.claimFromIpPoolAsTotalRnftOwner(address(7), address(USDC));

        uint256 usdcClaimerBalAfter = USDC.balanceOf(address(7));
        uint256 rnftClaimerBalAfter = ERC1155(address(splitClone7)).balanceOf(address(7), 0);

        assertApproxEqRel(usdcClaimerBalAfter - usdcClaimerBalBefore, royaltyAmountUSDC, 0.0001e18);
        assertEq(rnftClaimerBalAfter, 1000);
        assertEq(rnftClaimerBalBefore, 1000);
    }
}
