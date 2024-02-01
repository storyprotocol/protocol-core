// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;


import {console2} from "forge-std/console2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TestHelper } from "../../../utils/TestHelper.sol";
import { Errors } from "contracts/lib/Errors.sol";

contract TestRoyaltyModule is TestHelper {
    event RoyaltyPolicyWhitelistUpdated(address royaltyPolicy, bool allowed);
    event RoyaltyTokenWhitelistUpdated(address token, bool allowed);
    event RoyaltyPolicySet(address ipId, address royaltyPolicy, bytes data);
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);
    
    function setUp() public override {
        super.setUp();

        // fund WETH
        vm.startPrank(WETH_RICH);
        IERC20(WETH).transfer(ipAccount2, 1000 * 10 ** 6); // 1000 WETH
        vm.stopPrank();

        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);

        // whitelist royalty token
        royaltyModule.whitelistRoyaltyToken(WETH, true);
    }

    function test_RoyaltyModule_whitelistRoyaltyPolicy_revert_ZeroRoyaltyToken() public {
        vm.expectRevert(Errors.RoyaltyModule__ZeroRoyaltyToken.selector);

        royaltyModule.whitelistRoyaltyToken(address(0), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyPolicy() public {
        assertEq(royaltyModule.isWhitelistedRoyaltyPolicy(address(1)), false);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPolicyWhitelistUpdated(address(1), true);

        royaltyModule.whitelistRoyaltyPolicy(address(1), true);

        assertEq(royaltyModule.isWhitelistedRoyaltyPolicy(address(1)), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyToken_revert_ZeroRoyaltyPolicy() public {
        vm.expectRevert(Errors.RoyaltyModule__ZeroRoyaltyPolicy.selector);

        royaltyModule.whitelistRoyaltyPolicy(address(0), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyToken() public {
        assertEq(royaltyModule.isWhitelistedRoyaltyToken(address(1)), false);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyTokenWhitelistUpdated(address(1), true);

        royaltyModule.whitelistRoyaltyToken(address(1), true);

        assertEq(royaltyModule.isWhitelistedRoyaltyToken(address(1)), true);
    }

    function test_RoyaltyModule_setRoyaltyPolicy_revert_AlreadySetRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data);

        vm.expectRevert(Errors.RoyaltyModule__AlreadySetRoyaltyPolicy.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data);
    }

    function test_RoyaltyModule_setRoyaltyPolicy_revert_NotWhitelistedRoyaltyPolicy() public {
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);

        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(1), parentIpIds1, data);
    }

    function test_RoyaltyModule_setRoyaltyPolicy_revert_IncompatibleRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        address[] memory parentIpIds2 = new address[](1);
        parentIpIds2[0] = ipAccount1;
        uint32 minRoyaltyIpAccount2 = 100; // 10%
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);

        royaltyModule.whitelistRoyaltyPolicy(address(1), true);

        vm.expectRevert(Errors.RoyaltyModule__IncompatibleRoyaltyPolicy.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount2, address(1), parentIpIds2, data2);
    }

    function test_RoyaltyModule_setRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPolicySet(ipAccount1, address(royaltyPolicyLS), data);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data);

        assertEq(royaltyModule.royaltyPolicies(ipAccount1), address(royaltyPolicyLS));
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NoRoyaltyPolicySet() public {
        vm.expectRevert(Errors.RoyaltyModule__NoRoyaltyPolicySet.selector);

        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, WETH, 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyToken() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data);

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyToken.selector);
        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, address(1), 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data);

        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), false);

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, WETH, 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf() public {
         uint256 royaltyAmount = 100 * 10 ** 6; // 100 WETH

        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        address[] memory parentIpIds2 = new address[](0);
        uint32 minRoyaltyIpAccount2 = 100; // 10%
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);

        royaltyModule.setRoyaltyPolicy(ipAccount2, address(royaltyPolicyLS), parentIpIds2, data2);

        (address splitClone1,,,) = royaltyPolicyLS.royaltyData(ipAccount1);

        vm.startPrank(ipAccount2);
        IERC20(WETH).approve(address(royaltyPolicyLS), royaltyAmount);

        uint256 ipAccount2USDCBalBefore = IERC20(WETH).balanceOf(ipAccount2);
        uint256 splitClone1USDCBalBefore = IERC20(WETH).balanceOf(splitClone1);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPaid(ipAccount1, ipAccount2, ipAccount2, WETH, royaltyAmount);

        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, WETH, royaltyAmount);

        uint256 ipAccount2USDCBalAfter = IERC20(WETH).balanceOf(ipAccount2);
        uint256 splitClone1USDCBalAfter = IERC20(WETH).balanceOf(splitClone1);

        assertEq(ipAccount2USDCBalBefore - ipAccount2USDCBalAfter, royaltyAmount);
        assertEq(splitClone1USDCBalAfter - splitClone1USDCBalBefore, royaltyAmount);
    }
}