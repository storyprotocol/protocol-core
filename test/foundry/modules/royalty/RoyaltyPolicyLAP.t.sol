/* // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import { RoyaltyPolicyLAP } from "../../../../contracts/modules/royalty-module/policies/RoyaltyPolicyLAP.sol";
import { ILiquidSplitMain } from "../../../../contracts/interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
// tests
import { TestHelper } from "../../utils/TestHelper.sol";
import { console2 } from "forge-std/console2.sol";


contract TestRoyaltyPolicyLAP is TestHelper {
    event PolicyInitialized(address ipId, address splitClone, address claimer, uint32 royaltyStack, address[] targetAncestors, uint32[] targetRoyaltyAmount);

    struct InitParams {
        address[] targetAncestors;
        uint32[] targetRoyaltyAmount;
        uint32[] parentRoyalties;
        address[] parentAncestors1;
        address[] parentAncestors2;
        uint32[] parentAncestorsRoyalties1;
        uint32[] parentAncestorsRoyalties2;
    }

    RoyaltyPolicyLAP internal testRoyaltyPolicyLAP;

    InitParams initParamsMax;
    bytes MAX_ANCESTORS;
    address[] MAX_ANCESTORS_ = new address[](14);
    uint32[] MAX_ANCESTORS_ROYALTY_ = new uint32[](14);
    address[] parentsIpIds100;

    InitParams initParamsDuplicates;
    bytes DUPLICATE_ANCESTORS;
    address[] DUPLICATE_ANCESTORS_ = new address[](3);
    uint32[] DUPLICATE_ANCESTORS_ROYALTY_ = new uint32[](3);
    address[] parentsIpIds200;

    function setUp() public override {
        super.setUp();

        vm.startPrank(u.admin);
        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));
        _setupMaxUniqueTree();
        _setupDuplicatesTree();
    }

    function _setupMaxUniqueTree() internal {
        // init royalty policy for roots
        address[] memory nullTargetAncestors = new address[](0);
        uint32[] memory nullTargetRoyaltyAmount = new uint32[](0);
        uint32[] memory parentRoyalties = new uint32[](0);
        address[] memory nullParentAncestors1 = new address[](0);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory nullParentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory nullInitParams = InitParams({
            targetAncestors: nullTargetAncestors,
            targetRoyaltyAmount: nullTargetRoyaltyAmount,
            parentRoyalties: parentRoyalties,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        bytes memory nullBytes = abi.encode(nullInitParams);
        royaltyPolicyLAP.initPolicy(address(7), new address[](0), nullBytes);
        royaltyPolicyLAP.initPolicy(address(8), new address[](0), nullBytes);
        royaltyPolicyLAP.initPolicy(address(9), new address[](0), nullBytes);
        royaltyPolicyLAP.initPolicy(address(10), new address[](0), nullBytes);
        royaltyPolicyLAP.initPolicy(address(11), new address[](0), nullBytes);
        royaltyPolicyLAP.initPolicy(address(12), new address[](0), nullBytes);
        royaltyPolicyLAP.initPolicy(address(13), new address[](0), nullBytes);
        royaltyPolicyLAP.initPolicy(address(14), new address[](0), nullBytes);
 
        // init 2nd level with children
        address[] memory parents = new address[](2);
        address[] memory targetAncestors1 = new address[](2);
        uint32[] memory targetRoyaltyAmount1 = new uint32[](2);
        uint32[] memory parentRoyalties1 = new uint32[](2);

        // 3 is child of 7 and 8
        parents[0] = address(7);
        parents[1] = address(8);
        parentRoyalties1[0] = 7;
        parentRoyalties1[1] = 8;
        targetAncestors1[0] = address(7);
        targetAncestors1[1] = address(8);
        targetRoyaltyAmount1[0] = 7;
        targetRoyaltyAmount1[1] = 8;
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentRoyalties: parentRoyalties1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        bytes memory encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.initPolicy(address(3), parents, encodedBytes);

        // 4 is child of 9 and 10
        parents[0] = address(9);
        parents[1] = address(10);
        parentRoyalties1[0] = 9;
        parentRoyalties1[1] = 10;
        targetAncestors1[0] = address(9);
        targetAncestors1[1] = address(10);
        targetRoyaltyAmount1[0] = 9;
        targetRoyaltyAmount1[1] = 10;
        initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentRoyalties: parentRoyalties1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.initPolicy(address(4), parents, encodedBytes);

        // 5 is child of 11 and 12
        parents[0] = address(11);
        parents[1] = address(12);
        parentRoyalties1[0] = 11;
        parentRoyalties1[1] = 12;
        targetAncestors1[0] = address(11);
        targetAncestors1[1] = address(12);
        targetRoyaltyAmount1[0] = 11;
        targetRoyaltyAmount1[1] = 12;
        initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentRoyalties: parentRoyalties1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.initPolicy(address(5), parents, encodedBytes);

        
        // 6 is child of 13 and 14
        parents[0] = address(13);
        parents[1] = address(14);
        parentRoyalties1[0] = 13;
        parentRoyalties1[1] = 14;
        targetAncestors1[0] = address(13);
        targetAncestors1[1] = address(14);
        targetRoyaltyAmount1[0] = 13;
        targetRoyaltyAmount1[1] = 14;
        initParams = InitParams({
            targetAncestors: targetAncestors1,
            targetRoyaltyAmount: targetRoyaltyAmount1,
            parentRoyalties: parentRoyalties1,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.initPolicy(address(6), parents, encodedBytes);


        // init 3rd level with children
        address[] memory targetAncestors2 = new address[](6);
        uint32[] memory targetRoyaltyAmount2 = new uint32[](6);
        address[] memory parentAncestors1 = new address[](2);
        address[] memory parentAncestors2 = new address[](2);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](2);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](2);

        // 1 is child of 3 and 4
        parents[0] = address(3);
        parents[1] = address(4);
        parentRoyalties1[0] = 3;
        parentRoyalties1[1] = 4;
        parentAncestors1[0] = address(7);
        parentAncestors1[1] = address(8);
        parentAncestors2[0] = address(9);
        parentAncestors2[1] = address(10);
        parentAncestorsRoyalties1[0] = 7;
        parentAncestorsRoyalties1[1] = 8;
        parentAncestorsRoyalties2[0] = 9;
        parentAncestorsRoyalties2[1] = 10;
        targetAncestors2[0] = address(3);
        targetAncestors2[1] = address(7);
        targetAncestors2[2] = address(8);
        targetAncestors2[3] = address(4);
        targetAncestors2[4] = address(9);
        targetAncestors2[5] = address(10);
        targetRoyaltyAmount2[0] = 3;
        targetRoyaltyAmount2[1] = 7;
        targetRoyaltyAmount2[2] = 8;
        targetRoyaltyAmount2[3] = 4;
        targetRoyaltyAmount2[4] = 9;
        targetRoyaltyAmount2[5] = 10;
        initParams = InitParams({
            targetAncestors: targetAncestors2,
            targetRoyaltyAmount: targetRoyaltyAmount2,
            parentRoyalties: parentRoyalties1,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.initPolicy(address(1), parents, encodedBytes);

        // 2 is child of 5 and 6
        parents[0] = address(5);
        parents[1] = address(6);
        parentRoyalties1[0] = 5;
        parentRoyalties1[1] = 6;
        parentAncestors1[0] = address(11);
        parentAncestors1[1] = address(12);
        parentAncestors2[0] = address(13);
        parentAncestors2[1] = address(14);
        parentAncestorsRoyalties1[0] = 11;
        parentAncestorsRoyalties1[1] = 12;
        parentAncestorsRoyalties2[0] = 13;
        parentAncestorsRoyalties2[1] = 14;
        targetAncestors2[0] = address(5);
        targetAncestors2[1] = address(11);
        targetAncestors2[2] = address(12);
        targetAncestors2[3] = address(6);
        targetAncestors2[4] = address(13);
        targetAncestors2[5] = address(14);
        targetRoyaltyAmount2[0] = 5;
        targetRoyaltyAmount2[1] = 11;
        targetRoyaltyAmount2[2] = 12;
        targetRoyaltyAmount2[3] = 6;
        targetRoyaltyAmount2[4] = 13;
        targetRoyaltyAmount2[5] = 14;
        initParams = InitParams({
            targetAncestors: targetAncestors2,
            targetRoyaltyAmount: targetRoyaltyAmount2,
            parentRoyalties: parentRoyalties1,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.initPolicy(address(2), parents, encodedBytes);

        address[] memory parentAncestors3 = new address[](6);
        address[] memory parentAncestors4 = new address[](6);
        uint32[] memory parentAncestorsRoyalties3 = new uint32[](6);
        uint32[] memory parentAncestorsRoyalties4 = new uint32[](6);
        uint32[] memory parentRoyalties3 = new uint32[](2);

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

        parentAncestors3[0] = address(3);
        parentAncestors3[1] = address(7);
        parentAncestors3[2] = address(8);
        parentAncestors3[3] = address(4);
        parentAncestors3[4] = address(9);
        parentAncestors3[5] = address(10);
        parentAncestorsRoyalties3[0] = 3;
        parentAncestorsRoyalties3[1] = 7;
        parentAncestorsRoyalties3[2] = 8;
        parentAncestorsRoyalties3[3] = 4;
        parentAncestorsRoyalties3[4] = 9;
        parentAncestorsRoyalties3[5] = 10;

        parentAncestors4[0] = address(5);
        parentAncestors4[1] = address(11);
        parentAncestors4[2] = address(12);
        parentAncestors4[3] = address(6);
        parentAncestors4[4] = address(13);
        parentAncestors4[5] = address(14);
        parentAncestorsRoyalties4[0] = 5;
        parentAncestorsRoyalties4[1] = 11;
        parentAncestorsRoyalties4[2] = 12;
        parentAncestorsRoyalties4[3] = 6;
        parentAncestorsRoyalties4[4] = 13;
        parentAncestorsRoyalties4[5] = 14;

        parentRoyalties3[0] = 1;
        parentRoyalties3[1] = 2;

        initParamsMax = InitParams({
            targetAncestors: MAX_ANCESTORS_,
            targetRoyaltyAmount: MAX_ANCESTORS_ROYALTY_,
            parentRoyalties: parentRoyalties3,
            parentAncestors1: parentAncestors3,
            parentAncestors2: parentAncestors4,
            parentAncestorsRoyalties1: parentAncestorsRoyalties3,
            parentAncestorsRoyalties2: parentAncestorsRoyalties4
        });

        MAX_ANCESTORS = abi.encode(initParamsMax);

        parentsIpIds100 = new address[](2);
        parentsIpIds100[0] = address(1);
        parentsIpIds100[1] = address(2);
    }

    function _setupDuplicatesTree() internal {
        // init royalty policy for roots
        address[] memory nullTargetAncestors = new address[](0);
        uint32[] memory nullTargetRoyaltyAmount = new uint32[](0);
        uint32[] memory parentRoyalties = new uint32[](0);
        address[] memory nullParentAncestors1 = new address[](0);
        address[] memory nullParentAncestors2 = new address[](0);
        uint32[] memory nullParentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory nullParentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory nullInitParams = InitParams({
            targetAncestors: nullTargetAncestors,
            targetRoyaltyAmount: nullTargetRoyaltyAmount,
            parentRoyalties: parentRoyalties,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        bytes memory nullBytes = abi.encode(nullInitParams);
        royaltyPolicyLAP.initPolicy(address(15), new address[](0), nullBytes);

        // init 2nd level with children
        address[] memory parents5 = new address[](1);
        address[] memory targetAncestors5 = new address[](1);
        uint32[] memory targetRoyaltyAmount5 = new uint32[](1);
        uint32[] memory parentRoyalties5 = new uint32[](1);

        // 16 is child of 15 with 5% royalty
        parents5[0] = address(15);
        parentRoyalties5[0] = 50;
        targetAncestors5[0] = address(15);
        targetRoyaltyAmount5[0] = 50;
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors5,
            targetRoyaltyAmount: targetRoyaltyAmount5,
            parentRoyalties: parentRoyalties5,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        bytes memory encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.initPolicy(address(16), parents5, encodedBytes);

        // 17 is child of 15 with 10% royalty
        parents5[0] = address(15);
        parentRoyalties5[0] = 100;
        targetAncestors5[0] = address(15);
        targetRoyaltyAmount5[0] = 100;
        initParams = InitParams({
            targetAncestors: targetAncestors5,
            targetRoyaltyAmount: targetRoyaltyAmount5,
            parentRoyalties: parentRoyalties5,
            parentAncestors1: nullParentAncestors1,
            parentAncestors2: nullParentAncestors2,
            parentAncestorsRoyalties1: nullParentAncestorsRoyalties1,
            parentAncestorsRoyalties2: nullParentAncestorsRoyalties2
        });
        encodedBytes = abi.encode(initParams);
        royaltyPolicyLAP.initPolicy(address(17), parents5, encodedBytes);

        address[] memory parentAncestors16 = new address[](1);
        address[] memory parentAncestors17 = new address[](1);
        uint32[] memory parentAncestorsRoyalties16 = new uint32[](1);
        uint32[] memory parentAncestorsRoyalties17 = new uint32[](1);
        uint32[] memory parentRoyalties200 = new uint32[](2);

        DUPLICATE_ANCESTORS_[0] = address(16);
        DUPLICATE_ANCESTORS_[1] = address(15);
        DUPLICATE_ANCESTORS_[2] = address(17);

        DUPLICATE_ANCESTORS_ROYALTY_[0] = 50;
        DUPLICATE_ANCESTORS_ROYALTY_[1] = 150;
        DUPLICATE_ANCESTORS_ROYALTY_[2] = 20;

        parentAncestors16[0] = address(15);

        parentAncestors17[0] = address(15);

        parentAncestorsRoyalties16[0] = 50;

        parentAncestorsRoyalties17[0] = 100;

        parentRoyalties200[0] = 50;
        parentRoyalties200[1] = 20;

        initParamsDuplicates = InitParams({
            targetAncestors: DUPLICATE_ANCESTORS_,
            targetRoyaltyAmount: DUPLICATE_ANCESTORS_ROYALTY_,
            parentRoyalties: parentRoyalties200,
            parentAncestors1: parentAncestors16,
            parentAncestors2: parentAncestors17,
            parentAncestorsRoyalties1: parentAncestorsRoyalties16,
            parentAncestorsRoyalties2: parentAncestorsRoyalties17
        });

        DUPLICATE_ANCESTORS = abi.encode(initParamsDuplicates);

        parentsIpIds200 = new address[](2);
        parentsIpIds200[0] = address(16);
        parentsIpIds200[1] = address(17);
    }

    function test_setAncestorsVaultImplementation_ZeroAncestorsVaultImpl() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ZeroAncestorsVaultImpl.selector);
        royaltyPolicyLAP.setAncestorsVaultImplementation(address(0));
    }

    function test_setAncestorsVaultImplementation_ImplementationAlreadySet() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyPolicyLAP__ImplementationAlreadySet.selector);
        royaltyPolicyLAP.setAncestorsVaultImplementation(address(2));
    }

    function test_setAncestorsVaultImplementation() public {
        RoyaltyPolicyLAP royaltyPolicyLAP2 = new RoyaltyPolicyLAP(address(1), address(2), address(3), address(4), address(governance));
        
        vm.startPrank(u.admin);
        royaltyPolicyLAP2.setAncestorsVaultImplementation(address(2));

        assertEq(royaltyPolicyLAP2.ANCESTORS_VAULT_IMPL(), address(2));
    }

    function test_RoyaltyPolicyLAP_initPolicy_AboveAncestorsLimit() public {
        address[] memory targetAncestors = new address[](15);
        uint32[] memory targetRoyaltyAmount = new uint32[](0);
        uint32[] memory parentRoyalties = new uint32[](0);
        address[] memory parentAncestors1 = new address[](0);
        address[] memory parentAncestors2 = new address[](0);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentRoyalties: parentRoyalties,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        bytes memory inputBytes = abi.encode(initParams);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveAncestorsLimit.selector);
        royaltyPolicyLAP.initPolicy(address(30), new address[](0), inputBytes);
    }

    function test_RoyaltyPolicyLAP_initPolicy_AboveParentLimit() public {
        address[] memory targetAncestors = new address[](0);
        uint32[] memory targetRoyaltyAmount = new uint32[](0);
        uint32[] memory parentRoyalties = new uint32[](0);
        address[] memory parentAncestors1 = new address[](0);
        address[] memory parentAncestors2 = new address[](0);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentRoyalties: parentRoyalties,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        bytes memory inputBytes = abi.encode(initParams);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveParentLimit.selector);
        royaltyPolicyLAP.initPolicy(address(30), new address[](3), inputBytes);
    }

    function test_RoyaltyPolicyLAP_initPolicy_InvalidRoyaltyAmountLength() public {
        address[] memory targetAncestors = new address[](0);
        uint32[] memory targetRoyaltyAmount = new uint32[](1);
        uint32[] memory parentRoyalties = new uint32[](0);
        address[] memory parentAncestors1 = new address[](0);
        address[] memory parentAncestors2 = new address[](0);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentRoyalties: parentRoyalties,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        bytes memory inputBytes = abi.encode(initParams);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__InvalidRoyaltyAmountLength.selector);
        royaltyPolicyLAP.initPolicy(address(30), new address[](0), inputBytes);
    }

    function test_RoyaltyPolicyLAP_initPolicy_InvalidParentRoyaltiesLength() public {
        address[] memory targetAncestors = new address[](0);
        uint32[] memory targetRoyaltyAmount = new uint32[](0);
        uint32[] memory parentRoyalties = new uint32[](1);
        address[] memory parentAncestors1 = new address[](0);
        address[] memory parentAncestors2 = new address[](0);
        uint32[] memory parentAncestorsRoyalties1 = new uint32[](0);
        uint32[] memory parentAncestorsRoyalties2 = new uint32[](0);
        InitParams memory initParams = InitParams({
            targetAncestors: targetAncestors,
            targetRoyaltyAmount: targetRoyaltyAmount,
            parentRoyalties: parentRoyalties,
            parentAncestors1: parentAncestors1,
            parentAncestors2: parentAncestors2,
            parentAncestorsRoyalties1: parentAncestorsRoyalties1,
            parentAncestorsRoyalties2: parentAncestorsRoyalties2
        });
        bytes memory inputBytes = abi.encode(initParams);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__InvalidParentRoyaltiesLength.selector);
        royaltyPolicyLAP.initPolicy(address(30), new address[](0), inputBytes);
    }

    function test_RoyaltyPolicyLAP_initPolicy_InvalidAncestorsLength() public {
        address[] memory parentAncestors16 = new address[](1);
        address[] memory parentAncestors17 = new address[](1);
        uint32[] memory parentAncestorsRoyalties16 = new uint32[](1);
        uint32[] memory parentAncestorsRoyalties17 = new uint32[](1);
        uint32[] memory parentRoyalties200 = new uint32[](2);

        address[] memory INVALID_SHORT_ANCESTORS = new address[](4);
        uint32[] memory INVALID_SHORT_ANCESTORS_ROYALTY = new uint32[](4);

        INVALID_SHORT_ANCESTORS[0] = address(16);
        INVALID_SHORT_ANCESTORS[1] = address(15);
        INVALID_SHORT_ANCESTORS[2] = address(17);

        INVALID_SHORT_ANCESTORS_ROYALTY[0] = 50;
        INVALID_SHORT_ANCESTORS_ROYALTY[1] = 150;
        INVALID_SHORT_ANCESTORS_ROYALTY[2] = 20;

        parentAncestors16[0] = address(15);

        parentAncestors17[0] = address(15);

        parentAncestorsRoyalties16[0] = 50;

        parentAncestorsRoyalties17[0] = 100;

        parentRoyalties200[0] = 50;
        parentRoyalties200[1] = 20;

        initParamsDuplicates = InitParams({
            targetAncestors: INVALID_SHORT_ANCESTORS,
            targetRoyaltyAmount: INVALID_SHORT_ANCESTORS_ROYALTY,
            parentRoyalties: parentRoyalties200,
            parentAncestors1: parentAncestors16,
            parentAncestors2: parentAncestors17,
            parentAncestorsRoyalties1: parentAncestorsRoyalties16,
            parentAncestorsRoyalties2: parentAncestorsRoyalties17
        });

        DUPLICATE_ANCESTORS = abi.encode(initParamsDuplicates);

        parentsIpIds200 = new address[](2);
        parentsIpIds200[0] = address(16);
        parentsIpIds200[1] = address(17);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__InvalidAncestorsLength.selector);
        royaltyPolicyLAP.initPolicy(address(200), parentsIpIds200, DUPLICATE_ANCESTORS);
    }

    function test_RoyaltyPolicyLAP_initPolicy_InvalidAncestors() public {
        address[] memory parentAncestors16 = new address[](1);
        address[] memory parentAncestors17 = new address[](1);
        uint32[] memory parentAncestorsRoyalties16 = new uint32[](1);
        uint32[] memory parentAncestorsRoyalties17 = new uint32[](1);
        uint32[] memory parentRoyalties200 = new uint32[](2);

        DUPLICATE_ANCESTORS_[0] = address(16);
        DUPLICATE_ANCESTORS_[1] = address(150000000);
        DUPLICATE_ANCESTORS_[2] = address(17);

        DUPLICATE_ANCESTORS_ROYALTY_[0] = 50;
        DUPLICATE_ANCESTORS_ROYALTY_[1] = 150;
        DUPLICATE_ANCESTORS_ROYALTY_[2] = 20;

        parentAncestors16[0] = address(15);

        parentAncestors17[0] = address(15);

        parentAncestorsRoyalties16[0] = 50;

        parentAncestorsRoyalties17[0] = 100;

        parentRoyalties200[0] = 50;
        parentRoyalties200[1] = 20;

        initParamsDuplicates = InitParams({
            targetAncestors: DUPLICATE_ANCESTORS_,
            targetRoyaltyAmount: DUPLICATE_ANCESTORS_ROYALTY_,
            parentRoyalties: parentRoyalties200,
            parentAncestors1: parentAncestors16,
            parentAncestors2: parentAncestors17,
            parentAncestorsRoyalties1: parentAncestorsRoyalties16,
            parentAncestorsRoyalties2: parentAncestorsRoyalties17
        });

        DUPLICATE_ANCESTORS = abi.encode(initParamsDuplicates);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__InvalidAncestors.selector);
        royaltyPolicyLAP.initPolicy(address(200), parentsIpIds200, DUPLICATE_ANCESTORS);
    }

    function test_RoyaltyPolicyLAP_initPolicy_InvalidAncestorsRoyalty() public {
        address[] memory parentAncestors16 = new address[](1);
        address[] memory parentAncestors17 = new address[](1);
        uint32[] memory parentAncestorsRoyalties16 = new uint32[](1);
        uint32[] memory parentAncestorsRoyalties17 = new uint32[](1);
        uint32[] memory parentRoyalties200 = new uint32[](2);

        DUPLICATE_ANCESTORS_[0] = address(16);
        DUPLICATE_ANCESTORS_[1] = address(15);
        DUPLICATE_ANCESTORS_[2] = address(17);

        DUPLICATE_ANCESTORS_ROYALTY_[0] = 50;
        DUPLICATE_ANCESTORS_ROYALTY_[1] = 1500;
        DUPLICATE_ANCESTORS_ROYALTY_[2] = 20;

        parentAncestors16[0] = address(15);

        parentAncestors17[0] = address(15);

        parentAncestorsRoyalties16[0] = 50;

        parentAncestorsRoyalties17[0] = 100;

        parentRoyalties200[0] = 50;
        parentRoyalties200[1] = 20;

        initParamsDuplicates = InitParams({
            targetAncestors: DUPLICATE_ANCESTORS_,
            targetRoyaltyAmount: DUPLICATE_ANCESTORS_ROYALTY_,
            parentRoyalties: parentRoyalties200,
            parentAncestors1: parentAncestors16,
            parentAncestors2: parentAncestors17,
            parentAncestorsRoyalties1: parentAncestorsRoyalties16,
            parentAncestorsRoyalties2: parentAncestorsRoyalties17
        });

        DUPLICATE_ANCESTORS = abi.encode(initParamsDuplicates);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__InvalidAncestorsRoyalty.selector);
        royaltyPolicyLAP.initPolicy(address(200), parentsIpIds200, DUPLICATE_ANCESTORS);
    }

    function test_RoyaltyPolicyLAP_initPolicy_AboveRoyaltyStackLimit() public {
        address[] memory parentAncestors16 = new address[](1);
        address[] memory parentAncestors17 = new address[](1);
        uint32[] memory parentAncestorsRoyalties16 = new uint32[](1);
        uint32[] memory parentAncestorsRoyalties17 = new uint32[](1);
        uint32[] memory parentRoyalties200 = new uint32[](2);

        DUPLICATE_ANCESTORS_[0] = address(16);
        DUPLICATE_ANCESTORS_[1] = address(15);
        DUPLICATE_ANCESTORS_[2] = address(17);

        DUPLICATE_ANCESTORS_ROYALTY_[0] = 50;
        DUPLICATE_ANCESTORS_ROYALTY_[1] = 150;
        DUPLICATE_ANCESTORS_ROYALTY_[2] = 20;

        parentAncestors16[0] = address(15);

        parentAncestors17[0] = address(15);

        parentAncestorsRoyalties16[0] = 50;

        parentAncestorsRoyalties17[0] = 100;

        parentRoyalties200[0] = 5000;
        parentRoyalties200[1] = 20;

        initParamsDuplicates = InitParams({
            targetAncestors: DUPLICATE_ANCESTORS_,
            targetRoyaltyAmount: DUPLICATE_ANCESTORS_ROYALTY_,
            parentRoyalties: parentRoyalties200,
            parentAncestors1: parentAncestors16,
            parentAncestors2: parentAncestors17,
            parentAncestorsRoyalties1: parentAncestorsRoyalties16,
            parentAncestorsRoyalties2: parentAncestorsRoyalties17
        });

        DUPLICATE_ANCESTORS = abi.encode(initParamsDuplicates);

        parentsIpIds200 = new address[](2);
        parentsIpIds200[0] = address(16);
        parentsIpIds200[1] = address(17);

        vm.expectRevert(Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit.selector);
        royaltyPolicyLAP.initPolicy(address(200), parentsIpIds200, DUPLICATE_ANCESTORS);
    }

    function test_RoyaltyPolicyLAP_initPolicy_MaxAncestors() public {
        royaltyPolicyLAP.initPolicy(address(100), parentsIpIds100, MAX_ANCESTORS);

        (,address splitClone, address ancestorsVault, uint32 royaltyStack, bytes32 ancestorsHash) = royaltyPolicyLAP.royaltyData(address(100));

        assertEq(royaltyStack, 105);
        assertEq(ancestorsHash, keccak256(abi.encodePacked(MAX_ANCESTORS_, MAX_ANCESTORS_ROYALTY_)));
        assertFalse(splitClone == address(0));
        assertFalse(ancestorsVault == address(0));
    }
    
    function test_RoyaltyPolicyLAP_initPolicy_Root() public {
        (,address splitClone, address ancestorsVault, uint32 royaltyStack, bytes32 ancestorsHash) = royaltyPolicyLAP.royaltyData(address(7));

        assertEq(royaltyStack, 0);
        assertEq(ancestorsHash, keccak256(abi.encodePacked(new address[](0), new uint32[](0))));
        assertFalse(splitClone == address(0));
        assertEq(ancestorsVault, address(royaltyPolicyLAP));
    }

    function test_RoyaltyPolicyLAP_initPolicy_WithDuplicates() public {
        royaltyPolicyLAP.initPolicy(address(200), parentsIpIds200, DUPLICATE_ANCESTORS);

        (,address splitClone, address ancestorsVault, uint32 royaltyStack, bytes32 ancestorsHash) = royaltyPolicyLAP.royaltyData(address(200));

        assertEq(royaltyStack, 220);
        assertEq(ancestorsHash, keccak256(abi.encodePacked(DUPLICATE_ANCESTORS_, DUPLICATE_ANCESTORS_ROYALTY_)));
        assertFalse(splitClone == address(0));
        assertFalse(ancestorsVault == address(0));
    }

    function test_RoyaltyPolicyLAP_onRoyaltyPayment_NotRoyaltyModule() public {
        vm.stopPrank();
        vm.expectRevert(Errors.RoyaltyPolicyLAP__NotRoyaltyModule.selector);
        royaltyPolicyLAP.onRoyaltyPayment(address(1), address(1), address(1), 0);
    }

    function test_RoyaltyPolicyLAP_onRoyaltyPayment() public {
        (,address splitClone2, , , ) = royaltyPolicyLAP.royaltyData(address(2));
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
        (,address splitClone2, address ancestorsVault2, , ) = royaltyPolicyLAP.royaltyData(address(2));
        
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
        (,address splitClone2, address ancestorsVault2, , ) = royaltyPolicyLAP.royaltyData(address(2));
        
        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        accounts[0] = address(2);
        accounts[1] = ancestorsVault2;

        royaltyPolicyLAP.distributeIpPoolFunds(address(2), address(USDC), accounts, address(0));

        uint256 expectedAmountToBeClaimed = ILiquidSplitMain(royaltyPolicyLAP.LIQUID_SPLIT_MAIN()).getERC20Balance(address(2), USDC);

        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = USDC;

        uint256 splitMainUSDCBalBefore = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());
        uint256 address2USDCBalBefore = USDC.balanceOf(address(2));

        royaltyPolicyLAP.claimFromIpPool(address(2), 0, tokens);

        uint256 splitMainUSDCBalAfter = USDC.balanceOf(royaltyPolicyLAP.LIQUID_SPLIT_MAIN());
        uint256 address2USDCBalAfter = USDC.balanceOf(address(2));

        assertApproxEqRel(splitMainUSDCBalBefore - splitMainUSDCBalAfter, expectedAmountToBeClaimed, 0.0001e18);
        assertApproxEqRel(address2USDCBalAfter - address2USDCBalBefore, expectedAmountToBeClaimed, 0.0001e18);
    }

    function test_RoyaltyPolicyLAP_claimAsFullRnftOwner() public {
        (,address splitClone7, , , ) = royaltyPolicyLAP.royaltyData(address(7));

        uint256 royaltyAmountUSDC = 100 * 10 ** 6;
        USDC.mint(address(splitClone7), royaltyAmountUSDC);
        uint256 royaltyAmountETH = 1 ether;
        vm.deal(address(splitClone7), royaltyAmountETH);

        vm.startPrank(address(7));
        ERC1155(address(splitClone7)).setApprovalForAll(address(royaltyPolicyLAP), true);

        royaltyPolicyLAP.claimAsFullRnftOwner(address(7), 1, address(USDC));
    }
} */