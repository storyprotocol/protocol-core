// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Errors} from "contracts/lib/Errors.sol";
import {ArbitrationPolicySP} from "contracts/modules/dispute-module/policies/ArbitrationPolicySP.sol";
import {TestHelper} from "test/utils/TestHelper.sol";

contract TestArbitrationPolicySP is TestHelper {
    function setUp() public override {
        super.setUp();

        USDC.mint(ipAccount1, 1000 * 10 ** 6);

        // whitelist dispute tag
        disputeModule.whitelistDisputeTags("PLAGIARISM", true);

        // whitelist arbitration policy
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);

        // whitelist arbitration relayer
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), arbitrationRelayer, true);
    }

    function test_ArbitrationPolicySP_constructor_ZeroDisputeModule() public {
        address disputeModule = address(0);
        address paymentToken = address(1);
        uint256 arbitrationPrice = 1000;

        vm.expectRevert(Errors.ArbitrationPolicySP__ZeroDisputeModule.selector);
        new ArbitrationPolicySP(disputeModule, paymentToken, arbitrationPrice);
    }

    function test_ArbitrationPolicySP_constructor_ZeroPaymentToken() public {
        address disputeModule = address(1);
        address paymentToken = address(0);
        uint256 arbitrationPrice = 1000;

        vm.expectRevert(Errors.ArbitrationPolicySP__ZeroPaymentToken.selector);
        new ArbitrationPolicySP(disputeModule, paymentToken, arbitrationPrice);
    }

    function test_ArbitrationPolicySP_constructor() public {
        address disputeModule = address(1);
        address paymentToken = address(2);
        uint256 arbitrationPrice = 1000;

        ArbitrationPolicySP arbitrationPolicySP = new ArbitrationPolicySP(disputeModule, paymentToken, arbitrationPrice);

        assertEq(address(arbitrationPolicySP.DISPUTE_MODULE()), disputeModule);
        assertEq(address(arbitrationPolicySP.PAYMENT_TOKEN()), paymentToken);
        assertEq(arbitrationPolicySP.ARBITRATION_PRICE(), arbitrationPrice);
    }

    function test_ArbitrationPolicySP_onRaiseDispute_NotDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicySP__NotDisputeModule.selector);
        arbitrationPolicySP.onRaiseDispute(address(1), new bytes(0));
    }

    function test_ArbitrationPolicySP_onRaiseDispute() public {
        address caller = address(1);
        vm.startPrank(caller);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        vm.stopPrank();

        vm.startPrank(address(disputeModule));

        uint256 userUSDCBalBefore = IERC20(USDC).balanceOf(caller);
        uint256 arbitrationContractBalBefore = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        arbitrationPolicySP.onRaiseDispute(caller, new bytes(0));

        uint256 userUSDCBalAfter = IERC20(USDC).balanceOf(caller);
        uint256 arbitrationContractBalAfter = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        assertEq(userUSDCBalBefore - userUSDCBalAfter, ARBITRATION_PRICE);
        assertEq(arbitrationContractBalAfter - arbitrationContractBalBefore, ARBITRATION_PRICE);
    }

    function test_ArbitrationPolicySP_onDisputeJudgement_NotDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicySP__NotDisputeModule.selector);
        arbitrationPolicySP.onDisputeJudgement(1, true, new bytes(0));
    }

    function test_ArbitrationPolicySP_onDisputeJudgement_True() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAccount1, address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        uint256 ipAccount1USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        uint256 ipAccount1USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, ARBITRATION_PRICE);
    }

    function test_ArbitrationPolicySP_onDisputeJudgement_False() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAccount1, address(arbitrationPolicySP), string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        uint256 ipAccount1USDCBalanceBefore = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, false, "");

        uint256 ipAccount1USDCBalanceAfter = IERC20(USDC).balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = IERC20(USDC).balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, 0);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, 0);
    }

    function test_ArbitrationPolicySP_onDisputeCancel_NotDisputeModule() public {
        vm.expectRevert(Errors.ArbitrationPolicySP__NotDisputeModule.selector);
        arbitrationPolicySP.onDisputeCancel(address(1), 1, new bytes(0));
    }

    // TODO
    function test_ArbitrationPolicySP_withdraw() public {}
}
