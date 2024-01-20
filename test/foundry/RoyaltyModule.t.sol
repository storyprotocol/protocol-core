// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {console2} from "forge-std/console2.sol";
import {TestHelper} from "./../utils/TestHelper.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestRoyaltyModule is TestHelper {
    function setUp() public override {
        super.setUp();

        // fund USDC
        vm.startPrank(USDC_RICH);
        IERC20(USDC).transfer(ipAccount4, 1000 * 10 ** 6);
        vm.stopPrank();

        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyPolicy() public {
        assertEq(royaltyModule.isWhitelistedRoyaltyPolicy(address(royaltyPolicyLS)), true);
    }

    function test_RoyaltyModule_setRoyalty() public {
        vm.startPrank(ipAccount3);

        address[] memory accounts = new address[](2);
        accounts[0] = ipAccount1;
        accounts[1] = ipAccount2;

        uint32[] memory initAllocations = new uint32[](2);
        initAllocations[0] = 100;
        initAllocations[1] = 900;

        bytes memory data = abi.encode(accounts, initAllocations, uint32(0), address(0));

        royaltyModule.setRoyaltyPolicy(ipAccount3, address(royaltyPolicyLS), data);

        assertEq(royaltyModule.royaltyPolicies(ipAccount3), address(royaltyPolicyLS));
        // TODO: assertNotEq(royaltyModule.royaltyPolicies(ipAccount3), address(0)); // assertNotEq was deprecated?
    }

    function test_RoyaltyModule_payRoyalty() public {
        vm.startPrank(ipAccount3);

        address[] memory accounts = new address[](2);
        accounts[0] = ipAccount1;
        accounts[1] = ipAccount2;

        uint32[] memory initAllocations = new uint32[](2);
        initAllocations[0] = 100;
        initAllocations[1] = 900;

        bytes memory data = abi.encode(accounts, initAllocations, uint32(0), address(0));

        royaltyModule.setRoyaltyPolicy(ipAccount3, address(royaltyPolicyLS), data);
        vm.stopPrank();

        vm.startPrank(ipAccount4);
        uint256 royaltyAmount = 100 * 10 ** 6;
        IERC20(USDC).approve(address(royaltyPolicyLS), royaltyAmount);

        uint256 ipAccount4USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount4);
        uint256 splitCloneUSDCBalanceBefore = IERC20(USDC).balanceOf(royaltyPolicyLS.splitClones(ipAccount3));

        royaltyModule.payRoyalty(ipAccount3, USDC, royaltyAmount);

        uint256 ipAccount4USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount4);
        uint256 splitCloneUSDCBalanceAfter = IERC20(USDC).balanceOf(royaltyPolicyLS.splitClones(ipAccount3));

        assertEq(ipAccount4USDCBalanceBefore - ipAccount4USDCBalanceAfter, royaltyAmount);
        assertEq(splitCloneUSDCBalanceAfter - splitCloneUSDCBalanceBefore, royaltyAmount);
    }

    // TODO: move to royalty policy test file when created
    function test_RoyaltyModule_distributeFunds() public {
        vm.startPrank(ipAccount3);

        address[] memory accounts = new address[](2);
        accounts[0] = ipAccount1;
        accounts[1] = ipAccount2;

        uint32[] memory initAllocations = new uint32[](2);
        initAllocations[0] = 100;
        initAllocations[1] = 900;

        bytes memory data = abi.encode(accounts, initAllocations, uint32(0), address(0));

        royaltyModule.setRoyaltyPolicy(ipAccount3, address(royaltyPolicyLS), data);
        vm.stopPrank();

        vm.startPrank(ipAccount4);
        uint256 royaltyAmount = 100 * 10 ** 6;
        IERC20(USDC).approve(address(royaltyPolicyLS), royaltyAmount);

        royaltyModule.payRoyalty(ipAccount3, USDC, royaltyAmount);
        vm.stopPrank();

        vm.startPrank(ipAccount2);

        uint256 splitCloneUSDCBalanceBefore = IERC20(USDC).balanceOf(royaltyPolicyLS.splitClones(ipAccount3));
        uint256 splitMainUSDCBalanceBefore = IERC20(USDC).balanceOf(royaltyPolicyLS.LIQUID_SPLIT_MAIN());

        royaltyPolicyLS.distributeFunds(ipAccount3, USDC, accounts, address(2));

        uint256 splitCloneUSDCBalanceAfter = IERC20(USDC).balanceOf(royaltyPolicyLS.splitClones(ipAccount3));
        uint256 splitMainUSDCBalanceAfter = IERC20(USDC).balanceOf(royaltyPolicyLS.LIQUID_SPLIT_MAIN());

        assertApproxEqRel(splitCloneUSDCBalanceBefore - splitCloneUSDCBalanceAfter, royaltyAmount, 0.0001e18);
        assertApproxEqRel(splitMainUSDCBalanceAfter - splitMainUSDCBalanceBefore, royaltyAmount, 0.0001e18);
    }

    // TODO: move to royalty policy test file when created
    function test_RoyaltyModule_claimRoyalties() public {
        vm.startPrank(ipAccount3);

        address[] memory accounts = new address[](2);
        accounts[0] = ipAccount1;
        accounts[1] = ipAccount2;

        uint32[] memory initAllocations = new uint32[](2);
        initAllocations[0] = 100;
        initAllocations[1] = 900;

        bytes memory data = abi.encode(accounts, initAllocations, uint32(0), address(0));

        royaltyModule.setRoyaltyPolicy(ipAccount3, address(royaltyPolicyLS), data);
        vm.stopPrank();

        vm.startPrank(ipAccount4);
        uint256 royaltyAmount = 100 * 10 ** 6;
        IERC20(USDC).approve(address(royaltyPolicyLS), royaltyAmount);

        royaltyModule.payRoyalty(ipAccount3, USDC, royaltyAmount);
        vm.stopPrank();

        vm.startPrank(ipAccount2);
        royaltyPolicyLS.distributeFunds(ipAccount3, USDC, accounts, address(2));

        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = ERC20(USDC);

        uint256 ipAccount2USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount2);
        uint256 splitMainUSDCBalanceBefore = IERC20(USDC).balanceOf(royaltyPolicyLS.LIQUID_SPLIT_MAIN());

        royaltyPolicyLS.claimRoyalties(ipAccount2, 0, tokens);

        uint256 ipAccount2USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount2);
        uint256 splitMainUSDCBalanceAfter = IERC20(USDC).balanceOf(royaltyPolicyLS.LIQUID_SPLIT_MAIN());

        assertApproxEqRel(ipAccount2USDCBalanceAfter - ipAccount2USDCBalanceBefore, 90 * 10 ** 6, 0.0001e18);
        assertApproxEqRel(splitMainUSDCBalanceBefore - splitMainUSDCBalanceAfter, 90 * 10 ** 6, 0.0001e18);
    }
}
