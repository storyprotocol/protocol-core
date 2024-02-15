/* // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// contracts
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { Errors } from "contracts/lib/Errors.sol";
// tests
import { TestHelper } from "../../utils/TestHelper.sol";

contract TestRoyaltyModule is TestHelper {
    event RoyaltyPolicyWhitelistUpdated(address royaltyPolicy, bool allowed);
    event RoyaltyTokenWhitelistUpdated(address token, bool allowed);
    event RoyaltyPolicySet(address ipId, address royaltyPolicy, bytes data);
    event RoyaltyPaid(address receiverIpId, address payerIpId, address sender, address token, uint256 amount);

    function setUp() public override {
        super.setUp();

        USDC.mint(ipAccount2, 1000 * 10 ** 6); // 1000 USDC

        vm.startPrank(u.admin);
        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);

        // whitelist royalty token
        royaltyModule.whitelistRoyaltyToken(address(USDC), true);
        vm.stopPrank();
    }

    function test_RoyaltyModule_setLicensingModule_revert_ZeroLicensingModule() public {
        RoyaltyModule testRoyaltyModule = new RoyaltyModule(address(governance));
        vm.expectRevert(Errors.RoyaltyModule__ZeroLicensingModule.selector);
        vm.prank(u.admin);
        testRoyaltyModule.setLicensingModule(address(0));
    }

    function test_RoyaltyModule_setLicensingModule() public {
        vm.startPrank(u.admin);
        RoyaltyModule testRoyaltyModule = new RoyaltyModule(address(governance));
        testRoyaltyModule.setLicensingModule(address(licensingModule));

        assertEq(testRoyaltyModule.LICENSING_MODULE(), address(licensingModule));
    }

    function test_RoyaltyModule_whitelistRoyaltyPolicy_revert_ZeroRoyaltyToken() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyModule__ZeroRoyaltyToken.selector);

        royaltyModule.whitelistRoyaltyToken(address(0), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyPolicy() public {
        vm.startPrank(u.admin);
        assertEq(royaltyModule.isWhitelistedRoyaltyPolicy(address(1)), false);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPolicyWhitelistUpdated(address(1), true);

        royaltyModule.whitelistRoyaltyPolicy(address(1), true);

        assertEq(royaltyModule.isWhitelistedRoyaltyPolicy(address(1)), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyToken_revert_ZeroRoyaltyPolicy() public {
        vm.startPrank(u.admin);
        vm.expectRevert(Errors.RoyaltyModule__ZeroRoyaltyPolicy.selector);

        royaltyModule.whitelistRoyaltyPolicy(address(0), true);
    }

    function test_RoyaltyModule_whitelistRoyaltyToken() public {
        vm.startPrank(u.admin);
        assertEq(royaltyModule.isWhitelistedRoyaltyToken(address(1)), false);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyTokenWhitelistUpdated(address(1), true);

        royaltyModule.whitelistRoyaltyToken(address(1), true);

        assertEq(royaltyModule.isWhitelistedRoyaltyToken(address(1)), true);
    }

    function test_RoyaltyModule_setRoyaltyPolicy_revert_NotAllowedCaller() public {
        address[] memory parentIpIds = new address[](0);
        uint32 minRoyaltyIpAccount = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount);

        vm.expectRevert(Errors.RoyaltyModule__NotAllowedCaller.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds, data);
    }

    function test_RoyaltyModule_setRoyaltyPolicy_revert_AlreadySetRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);

        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        address[] memory parentIpIds2 = new address[](1);
        parentIpIds2[0] = ipAccount1;
        uint32 minRoyaltyIpAccount2 = 100; // 10%
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);

        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds2, data2);

        vm.expectRevert(Errors.RoyaltyModule__AlreadySetRoyaltyPolicy.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        vm.expectRevert(Errors.RoyaltyModule__AlreadySetRoyaltyPolicy.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds2, data2);
    }

    function test_RoyaltyModule_setRoyaltyPolicy_revert_NotWhitelistedRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(1), parentIpIds1, data);
    }

    function test_RoyaltyModule_setRoyaltyPolicy_revert_IncompatibleRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);

        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);
        vm.stopPrank();

        address[] memory parentIpIds2 = new address[](1);
        parentIpIds2[0] = ipAccount1;
        uint32 minRoyaltyIpAccount2 = 100; // 10%
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(1), true);
        vm.stopPrank();

        vm.startPrank(address(licensingModule));
        vm.expectRevert(Errors.RoyaltyModule__IncompatibleRoyaltyPolicy.selector);
        royaltyModule.setRoyaltyPolicy(ipAccount2, address(1), parentIpIds2, data2);
    }

    function test_RoyaltyModule_setRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPolicySet(ipAccount1, address(royaltyPolicyLS), data);

        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data);

        assertEq(royaltyModule.royaltyPolicies(ipAccount1), address(royaltyPolicyLS));
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NoRoyaltyPolicySet() public {
        vm.expectRevert(Errors.RoyaltyModule__NoRoyaltyPolicySet.selector);

        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, address(USDC), 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyToken() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data);
        vm.stopPrank();

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyToken.selector);
        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, address(1), 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf_revert_NotWhitelistedRoyaltyPolicy() public {
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data);
        vm.stopPrank();

        vm.startPrank(u.admin);
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), false);

        vm.expectRevert(Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy.selector);
        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, address(USDC), 100);
    }

    function test_RoyaltyModule_payRoyaltyOnBehalf() public {
        uint256 royaltyAmount = 100 * 10 ** 6;

        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100; // 10%
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);

        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);

        address[] memory parentIpIds2 = new address[](0);
        uint32 minRoyaltyIpAccount2 = 100; // 10%
        bytes memory data2 = abi.encode(minRoyaltyIpAccount2);

        royaltyModule.setRoyaltyPolicy(ipAccount2, address(royaltyPolicyLS), parentIpIds2, data2);
        vm.stopPrank();

        (address splitClone1, , , ) = royaltyPolicyLS.royaltyData(ipAccount1);

        vm.startPrank(ipAccount2);
        USDC.approve(address(royaltyPolicyLS), royaltyAmount);

        uint256 ipAccount2USDCBalBefore = USDC.balanceOf(ipAccount2);
        uint256 splitClone1USDCBalBefore = USDC.balanceOf(splitClone1);

        vm.expectEmit(true, true, true, true, address(royaltyModule));
        emit RoyaltyPaid(ipAccount1, ipAccount2, ipAccount2, address(USDC), royaltyAmount);

        royaltyModule.payRoyaltyOnBehalf(ipAccount1, ipAccount2, address(USDC), royaltyAmount);

        uint256 ipAccount2USDCBalAfter = USDC.balanceOf(ipAccount2);
        uint256 splitClone1USDCBalAfter = USDC.balanceOf(splitClone1);

        assertEq(ipAccount2USDCBalBefore - ipAccount2USDCBalAfter, royaltyAmount);
        assertEq(splitClone1USDCBalAfter - splitClone1USDCBalBefore, royaltyAmount);
    }
}
 */