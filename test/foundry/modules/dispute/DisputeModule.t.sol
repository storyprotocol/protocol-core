// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Errors} from "contracts/lib/Errors.sol";
import {ShortStringOps} from "contracts/utils/ShortStringOps.sol";
import {DisputeModule} from "contracts/modules/dispute-module/DisputeModule.sol";
import {TestHelper} from "test/utils/TestHelper.sol";

contract TestDisputeModule is TestHelper {
    event TagWhitelistUpdated(bytes32 tag, bool allowed);
    event ArbitrationPolicyWhitelistUpdated(address arbitrationPolicy, bool allowed);
    event ArbitrationRelayerWhitelistUpdated(address arbitrationPolicy, address arbitrationRelayer, bool allowed);
    event DisputeRaised(
        uint256 disputeId,
        address targetIpId,
        address disputeInitiator,
        address arbitrationPolicy,
        bytes32 linkToDisputeEvidence,
        bytes32 targetTag,
        bytes data
    );
    event DisputeJudgementSet(uint256 disputeId, bool decision, bytes data);
    event DisputeCancelled(uint256 disputeId, bytes data);
    event DisputeResolved(uint256 disputeId);

    function setUp() public override {
        super.setUp();

        // fund WETH
        vm.startPrank(WETH_RICH);
        IERC20(WETH).transfer(ipAccount1, ARBITRATION_PRICE);
        vm.stopPrank();

        // whitelist dispute tag
        disputeModule.whitelistDisputeTags("PLAGIARISM", true);

        // whitelist arbitration policy
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);

        // whitelist arbitration relayer
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), arbitrationRelayer, true);
    }

    function test_DisputeModule_whitelistDisputeTags_ZeroDisputeTag() public {
        vm.expectRevert(Errors.DisputeModule__ZeroDisputeTag.selector);
        disputeModule.whitelistDisputeTags(bytes32(0), true);
    }

    function test_DisputeModule_whitelistDisputeTags() public {
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit TagWhitelistUpdated(bytes32("INAPPROPRIATE_CONTENT"), true);

        disputeModule.whitelistDisputeTags("INAPPROPRIATE_CONTENT", true);
        assertEq(disputeModule.isWhitelistedDisputeTag("INAPPROPRIATE_CONTENT"), true);
    }

    function test_DisputeModule_whitelistArbitrationPolicy_ZeroArbitrationPolicy() public {
        vm.expectRevert(Errors.DisputeModule__ZeroArbitrationPolicy.selector);
        disputeModule.whitelistArbitrationPolicy(address(0), true);
    }

    function test_DisputeModule_whitelistArbitrationPolicy() public {
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationPolicyWhitelistUpdated(address(1), true);

        disputeModule.whitelistArbitrationPolicy(address(1), true);

        assertEq(disputeModule.isWhitelistedArbitrationPolicy(address(1)), true);
    }

    function test_DisputeModule_whitelistArbitrationRelayer_ZeroArbitrationPolicy() public {
        vm.expectRevert(Errors.DisputeModule__ZeroArbitrationPolicy.selector);
        disputeModule.whitelistArbitrationRelayer(address(0), arbitrationRelayer, true);
    }

    function test_DisputeModule_whitelistArbitrationRelayer_ZeroArbitrationRelayer() public {
        vm.expectRevert(Errors.DisputeModule__ZeroArbitrationRelayer.selector);
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), address(0), true);
    }

    function test_DisputeModule_whitelistArbitrationRelayer() public {
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit ArbitrationRelayerWhitelistUpdated(address(arbitrationPolicySP), address(1), true);

        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), address(1), true);

        assertEq(disputeModule.isWhitelistedArbitrationRelayer(address(arbitrationPolicySP), address(1)), true);
    }

    function test_DisputeModule_PolicySP_raiseDispute_NotWhitelistedArbitrationPolicy() public {
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationPolicy.selector);
        disputeModule.raiseDispute(address(1), address(1), string("urlExample"), "PLAGIARISM", "");
    }

    function test_DisputeModule_PolicySP_raiseDispute_NotWhitelistedDisputeTag() public {
        vm.expectRevert(Errors.DisputeModule__NotWhitelistedDisputeTag.selector);
        disputeModule.raiseDispute(
            address(1), address(arbitrationPolicySP), string("urlExample"), "NOT_WHITELISTED", ""
        );
    }

    function test_DisputeModule_PolicySP_raiseDispute_ZeroLinkToDisputeEvidence() public {
        vm.expectRevert(Errors.DisputeModule__ZeroLinkToDisputeEvidence.selector);
        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string(""), "PLAGIARISM", "");
    }

    function test_DisputeModule_PolicySP_raiseDispute() public {
        vm.startPrank(ipAccount1);

        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);

        uint256 disputeIdBefore = disputeModule.disputeId();
        uint256 ipAccount1USDCBalanceBefore = IERC20(WETH).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = IERC20(WETH).balanceOf(address(arbitrationPolicySP));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeRaised(
            disputeIdBefore + 1,
            ipAccount2,
            ipAccount1,
            address(arbitrationPolicySP),
            ShortStringOps.stringToBytes32("urlExample"),
            bytes32("PLAGIARISM"),
            ""
        );

        disputeModule.raiseDispute(ipAccount2, address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");

        uint256 disputeIdAfter = disputeModule.disputeId();
        uint256 ipAccount1USDCBalanceAfter = IERC20(WETH).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = IERC20(WETH).balanceOf(address(arbitrationPolicySP));

        (
            address targetIpId,
            address disputeInitiator,
            address arbitrationPolicy,
            bytes32 linkToDisputeEvidence,
            bytes32 targetTag,
            bytes32 currentTag
        ) = disputeModule.disputes(disputeIdAfter);

        assertEq(disputeIdAfter - disputeIdBefore, 1);
        assertEq(ipAccount1USDCBalanceBefore - ipAccount1USDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceAfter - arbitrationPolicySPUSDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(targetIpId, ipAccount2);
        assertEq(disputeInitiator, ipAccount1);
        assertEq(arbitrationPolicy, address(arbitrationPolicySP));
        assertEq(linkToDisputeEvidence, ShortStringOps.stringToBytes32("urlExample"));
        assertEq(targetTag, bytes32("PLAGIARISM"));
        assertEq(currentTag, bytes32("IN_DISPUTE"));
    }

    function test_DisputeModule_PolicySP_setDisputeJudgement_NotInDisputeState() public {
        vm.expectRevert(Errors.DisputeModule__NotInDisputeState.selector);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_PolicySP_setDisputeJudgement_NotWhitelistedArbitrationRelayer() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAccount2, address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotWhitelistedArbitrationRelayer.selector);
        disputeModule.setDisputeJudgement(1, true, "");
    }

    function test_DisputeModule_PolicySP_setDisputeJudgement_True() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAccount1, address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        (,,,,, bytes32 currentTagBefore) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceBefore = IERC20(WETH).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = IERC20(WETH).balanceOf(address(arbitrationPolicySP));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeJudgementSet(1, true, "");

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        (,,,,, bytes32 currentTagAfter) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceAfter = IERC20(WETH).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = IERC20(WETH).balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, ARBITRATION_PRICE);
        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32("PLAGIARISM"));
    }

    function test_DisputeModule_PolicySP_setDisputeJudgement_False() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAccount1, address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        (,,,,, bytes32 currentTagBefore) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceBefore = IERC20(WETH).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = IERC20(WETH).balanceOf(address(arbitrationPolicySP));

        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeJudgementSet(1, false, "");

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, false, "");

        (,,,,, bytes32 currentTagAfter) = disputeModule.disputes(1);
        uint256 ipAccount1USDCBalanceAfter = IERC20(WETH).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = IERC20(WETH).balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, 0);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, 0);
        assertEq(currentTagBefore, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfter, bytes32(0));
    }

    function test_DisputeModule_PolicySP_cancelDispute_NotDisputeInitiator() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.cancelDispute(1, "");
    }

    function test_DisputeModule_PolicySP_cancelDispute_NotInDisputeState() public {
        vm.expectRevert(Errors.DisputeModule__NotInDisputeState.selector);
        disputeModule.cancelDispute(1, "");
    }

    function test_DisputeModule_PolicySP_cancelDispute() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        (,,,,, bytes32 currentTagBeforeCancel) = disputeModule.disputes(1);

        vm.startPrank(ipAccount1);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeCancelled(1, "");

        disputeModule.cancelDispute(1, "");
        vm.stopPrank();

        (,,,,, bytes32 currentTagAfterCancel) = disputeModule.disputes(1);

        assertEq(currentTagBeforeCancel, bytes32("IN_DISPUTE"));
        assertEq(currentTagAfterCancel, bytes32(0));
    }

    function test_DisputeModule_resolveDispute_NotDisputeInitiator() public {
        vm.expectRevert(Errors.DisputeModule__NotDisputeInitiator.selector);
        disputeModule.resolveDispute(1);
    }

    function test_DisputeModule_resolveDispute_NotAbleToResolve() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        vm.startPrank(ipAccount1);
        vm.expectRevert(Errors.DisputeModule__NotAbleToResolve.selector);
        disputeModule.resolveDispute(1);
    }

    function test_DisputeModule_resolveDispute() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(address(1), address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");
        vm.stopPrank();

        (,,,,, bytes32 currentTagBeforeResolve) = disputeModule.disputes(1);

        // resolve dispute
        vm.startPrank(ipAccount1);
        vm.expectEmit(true, true, true, true, address(disputeModule));
        emit DisputeResolved(1);

        disputeModule.resolveDispute(1);

        (,,,,, bytes32 currentTagAfterResolve) = disputeModule.disputes(1);

        assertEq(currentTagBeforeResolve, bytes32("PLAGIARISM"));
        assertEq(currentTagAfterResolve, bytes32(0));
    }
}
