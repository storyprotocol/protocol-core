// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { TestHelper } from "../../../utils/TestHelper.sol";
import { RoyaltyPolicyLS } from "../../../../contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { ILiquidSplitClone } from "../../../../contracts/interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

contract TestLSClaimer is TestHelper {
    RoyaltyPolicyLS internal testRoyaltyPolicyLS;

    function setUp() public override {
        super.setUp();

        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);
    }

    function test_RoyaltyPolicyLS_constructor_revert_ZeroRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLS__ZeroRoyaltyModule.selector);

        testRoyaltyPolicyLS = new RoyaltyPolicyLS(address(0), address(1), LIQUID_SPLIT_FACTORY, LIQUID_SPLIT_MAIN);
    }

    function test_RoyaltyPolicyLS_constructor_revert_ZeroLicenseRegistry() public {
        vm.expectRevert(Errors.RoyaltyPolicyLS__ZeroLicenseRegistry.selector);

        testRoyaltyPolicyLS = new RoyaltyPolicyLS(address(royaltyModule), address(0), LIQUID_SPLIT_FACTORY, LIQUID_SPLIT_MAIN);
    }

    function test_RoyaltyPolicyLS_constructor_revert_ZeroLiquidSplitFactory() public {
        vm.expectRevert(Errors.RoyaltyPolicyLS__ZeroLiquidSplitFactory.selector);

        testRoyaltyPolicyLS = new RoyaltyPolicyLS(address(royaltyModule), address(1), address(0), LIQUID_SPLIT_MAIN);
    }

    function test_RoyaltyPolicyLS_constructor_revert_ZeroLiquidSplitMain() public {
        vm.expectRevert(Errors.RoyaltyPolicyLS__ZeroLiquidSplitMain.selector);

        testRoyaltyPolicyLS = new RoyaltyPolicyLS(address(royaltyModule), address(1), LIQUID_SPLIT_FACTORY, address(0));
    }

    function test_RoyaltyPolicyLS_constructor() public {
        testRoyaltyPolicyLS = new RoyaltyPolicyLS(address(royaltyModule), address(1), LIQUID_SPLIT_FACTORY, LIQUID_SPLIT_MAIN);

        assertEq(testRoyaltyPolicyLS.ROYALTY_MODULE(), address(royaltyModule));
        assertEq(testRoyaltyPolicyLS.LICENSE_REGISTRY(), address(1));
        assertEq(testRoyaltyPolicyLS.LIQUID_SPLIT_FACTORY(), LIQUID_SPLIT_FACTORY);
        assertEq(testRoyaltyPolicyLS.LIQUID_SPLIT_MAIN(), LIQUID_SPLIT_MAIN);
        
    }

    function test_RoyaltyPolicyLS_revert_InvalidMinRoyalty() public {
        // set root parent royalty policy
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; 
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        // set derivative royalty policy
        address[] memory parentIpIds2 = new address[](1);
        parentIpIds2[0] = ipAccount1;
        uint32 minRoyaltyIpAccount2 = 5;
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);

        vm.expectRevert(Errors.RoyaltyPolicyLS__InvalidMinRoyalty.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount2, address(royaltyPolicyLS), parentIpIds2, data2);
    }

    function test_RoyaltyPolicyLS_revert_ZeroMinRoyalty() public {
        // set root parent royalty policy
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; 
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        // set derivative royalty policy
        address[] memory parentIpIds2 = new address[](1);
        parentIpIds2[0] = ipAccount1;
        uint32 minRoyaltyIpAccount2 = 0;
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);

        vm.expectRevert(Errors.RoyaltyPolicyLS__ZeroMinRoyalty.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount2, address(royaltyPolicyLS), parentIpIds2, data2);
    }

    function test_RoyaltyPolicyLS_revert_InvalidRoyaltyStack() public {
        address[] memory parentIpIds = new address[](0);
        uint32 minRoyaltyIpAccount3 = 1010; // 100.1%
        bytes memory data = abi.encode(minRoyaltyIpAccount3);

        vm.expectRevert(Errors.RoyaltyPolicyLS__InvalidRoyaltyStack.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount3, address(royaltyPolicyLS), parentIpIds, data);
    }

    function test_RoyaltyPolicyLS_initPolicy_rootIPA() public {
        address[] memory parentIpIds = new address[](0);
        uint32 minRoyaltyIpAccount1 = 0; 
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds, data);

        (address splitClone, address claimer, uint32 royaltyStack, uint32 minRoyalty) = royaltyPolicyLS.royaltyData(ipAccount1);

        assertFalse(splitClone == address(0));
        assertEq(claimer, address(royaltyPolicyLS));
        assertEq(royaltyStack, minRoyaltyIpAccount1);
        assertEq(minRoyalty, minRoyaltyIpAccount1);
    }

    function test_RoyaltyPolicyLS_initPolicy_derivativeIPA() public {
        // set root parent royalty policy
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; 
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        // set derivative royalty policy
        address[] memory parentIpIds2 = new address[](1);
        parentIpIds2[0] = ipAccount1;
        uint32 minRoyaltyIpAccount2 = 200; 
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);
        royaltyModule.setRoyaltyPolicy(ipAccount2, address(royaltyPolicyLS), parentIpIds2, data2);

        (address splitClone, address claimer, uint32 royaltyStack, uint32 minRoyalty) = royaltyPolicyLS.royaltyData(ipAccount2);

        assertFalse(splitClone == address(0));
        assertFalse(claimer == address(royaltyPolicyLS));
        assertFalse(claimer == address(0));
        assertEq(royaltyStack, minRoyaltyIpAccount1 + minRoyaltyIpAccount2);
        assertEq(minRoyalty, minRoyaltyIpAccount2);
    }

    function test_RoyaltyPolicyLS_distributeFunds() public {
        // set root parent royalty policy
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; 
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        // set derivative royalty policy
        address[] memory parentIpIds2 = new address[](1);
        parentIpIds2[0] = ipAccount1;
        uint32 minRoyaltyIpAccount2 = 200; 
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);
        royaltyModule.setRoyaltyPolicy(ipAccount2, address(royaltyPolicyLS), parentIpIds2, data2);
        (address splitClone2, address claimer2,,) = royaltyPolicyLS.royaltyData(ipAccount2);

        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        accounts[0] = ipAccount2;
        accounts[1] = claimer2;

        uint256 splitClone2USDCBalBefore = IERC20(WETH).balanceOf(splitClone2);
        uint256 splitMainUSDCBalBefore = IERC20(WETH).balanceOf(royaltyPolicyLS.LIQUID_SPLIT_MAIN());

        royaltyPolicyLS.distributeFunds(ipAccount2, address(USDC), accounts, address(0));

        uint256 splitClone2USDCBalAfter = IERC20(WETH).balanceOf(splitClone2);
        uint256 splitMainUSDCBalAfter = IERC20(WETH).balanceOf(royaltyPolicyLS.LIQUID_SPLIT_MAIN());

        assertApproxEqRel(splitClone2USDCBalBefore - splitClone2USDCBalAfter, royaltyAmount, 0.0001e18);
        assertApproxEqRel(splitMainUSDCBalAfter - splitMainUSDCBalBefore, royaltyAmount, 0.0001e18);
    }

    function test_RoyaltyPolicyLS_claimRoyalties() public{
        // set root parent royalty policy
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; 
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        // set derivative royalty policy
        address[] memory parentIpIds2 = new address[](1);
        parentIpIds2[0] = ipAccount1;
        uint32 minRoyaltyIpAccount2 = 200; 
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);
        royaltyModule.setRoyaltyPolicy(ipAccount2, address(royaltyPolicyLS), parentIpIds2, data2);
        (address splitClone2, address claimer2,,) = royaltyPolicyLS.royaltyData(ipAccount2);

        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        accounts[0] = ipAccount2;
        accounts[1] = claimer2;

        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = ERC20(WETH);

        royaltyPolicyLS.distributeFunds(ipAccount2, address(USDC), accounts, address(0));

        royaltyPolicyLS.claimRoyalties(ipAccount2, 0, tokens);
    }
}