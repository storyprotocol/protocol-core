// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {console2} from "forge-std/console2.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {TestHelper} from "./../utils/TestHelper.sol";
import {ShortStringOps} from "./../../contracts/utils/ShortStringOps.sol";

import {Errors} from "contracts/lib/Errors.sol";
import {ShortStringEquals} from "contracts/utils/ShortStringOps.sol";
import {TestHelper} from "test/utils/TestHelper.sol";

contract TestDisputeModule is TestHelper {
    function setUp() public override {
        super.setUp();

        // fund USDC
        vm.startPrank(USDC_RICH);
        IERC20(USDC).transfer(ipAccount1, 1000 * 10 ** 6);
        vm.stopPrank();

        // whitelist dispute tag
        disputeModule.whitelistDisputeTags("plagiarism", true);

        // whitelist arbitration policy
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);

        // whitelist arbitration relayer
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), arbitrationRelayer, true);
    }

    function test_DisputeModule_whitelistDisputeTags() public {
        assertEq(disputeModule.isWhitelistedDisputeTag("plagiarism"), true);
    }

    function test_DisputeModule_whitelistArbitrationPolicy() public {
        assertEq(disputeModule.isWhitelistedArbitrationPolicy(address(arbitrationPolicySP)), true);
    }

    function test_DisputeModule_whitelistArbitrationRelayer() public {
        assertEq(
            disputeModule.isWhitelistedArbitrationRelayer(address(arbitrationPolicySP), address(arbitrationRelayer)),
            true
        );
    }

    function test_DisputeModule_raiseDispute() public {
        vm.startPrank(ipAccount1);

        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeId();
        uint256 ipAccount1USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationPolicy.selector);
        disputeModule.raiseDispute(address(1), address(0xbeef), string("urlExample"), "plagiarism", "");

        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string("urlExample"), "plagiarism", "");

        uint256 disputeIdAfter = disputeModule.disputeId();
        uint256 ipAccount1USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        (address ip_id, address disputeInitiator, address arbitrationPolicy, bytes32 linkToDisputeSummary, bytes32 tag)
        = disputeModule.disputes(disputeIdAfter);

        assertEq(disputeIdAfter - disputeIdBefore, 1);
        assertEq(ipAccount1USDCBalanceBefore - ipAccount1USDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceAfter - arbitrationPolicySPUSDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(ip_id, address(1));
        assertEq(disputeInitiator, ipAccount1);
        assertEq(arbitrationPolicy, address(arbitrationPolicySP));
        assertEq(linkToDisputeSummary, ShortStringOps.stringToBytes32("urlExample"));
        assertEq(tag, bytes32("plagiarism"));
    }

    function test_DisputeModule_setDisputeJudgement() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string("urlExample"), "plagiarism", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        uint256 ipAccount1USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        vm.startPrank(address(0xdeadbeef));
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationRelayer.selector);
        disputeModule.setDisputeJudgement(1, false, "");
        vm.stopPrank();

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        uint256 ipAccount1USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = IERC20(USDC).balanceOf(address(arbitrationPolicySP));
        vm.stopPrank();

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, ARBITRATION_PRICE);
    }

    // TODO
    function test_DisputeModule_cancelDispute() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string("urlExample"), "plagiarism", "");
        vm.stopPrank();

        // cancel dispute

        vm.prank(address(0xdeadbeef));
        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.cancelDispute(1, "");

        vm.startPrank(ipAccount1);
        disputeModule.cancelDispute(1, "");
        vm.stopPrank();
    }

    // TODO
    function test_DisputeModule_resolveDispute() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string("urlExample"), "plagiarism", "");
        vm.stopPrank();

        // resolve dispute
        vm.prank(address(0xdeadbeef));
        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.resolveDispute(1);
    }
}
