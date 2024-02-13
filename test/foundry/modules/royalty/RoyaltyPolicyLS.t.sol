// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// contracts
import { RoyaltyPolicyLS } from "../../../../contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
// tests
import { BaseTest } from "../../utils/BaseTest.sol";

contract TestLSClaimer is BaseTest {
    RoyaltyPolicyLS internal testRoyaltyPolicyLS;

    address internal ipAccount1 = address(0x111000aaa);
    address internal ipAccount2 = address(0x111000bbb);
    address internal ipAccount3 = address(0x111000ccc);

    function setUp() public override {
        super.setUp();
        buildDeployModuleCondition(
            DeployModuleCondition({
                registrationModule: false,
                disputeModule: false,
                royaltyModule: true,
                taggingModule: false,
                licensingModule: false
            })
        );
        buildDeployPolicyCondition(DeployPolicyCondition({ arbitrationPolicySP: false, royaltyPolicyLS: true }));
        deployConditionally();
        postDeploymentSetup();
    }

    function test_RoyaltyPolicyLS_constructor_revert_ZeroRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLS__ZeroRoyaltyModule.selector);

        testRoyaltyPolicyLS = new RoyaltyPolicyLS(address(0), address(1), LIQUID_SPLIT_FACTORY, LIQUID_SPLIT_MAIN);
    }

    function test_RoyaltyPolicyLS_constructor_revert_ZeroLicensingModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLS__ZeroLicensingModule.selector);

        testRoyaltyPolicyLS = new RoyaltyPolicyLS(
            address(royaltyModule),
            address(0),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN
        );
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
        testRoyaltyPolicyLS = new RoyaltyPolicyLS(
            address(royaltyModule),
            address(1),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN
        );

        assertEq(testRoyaltyPolicyLS.ROYALTY_MODULE(), address(royaltyModule));
        assertEq(testRoyaltyPolicyLS.LICENSING_MODULE(), address(1));
        assertEq(testRoyaltyPolicyLS.LIQUID_SPLIT_FACTORY(), LIQUID_SPLIT_FACTORY);
        assertEq(testRoyaltyPolicyLS.LIQUID_SPLIT_MAIN(), LIQUID_SPLIT_MAIN);
    }

    function test_RoyaltyPolicyLS_initPolicy_NotRoyalModule() public {
        vm.startPrank(address(licensingModule));
        address[] memory parentIpIds = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100;
        bytes memory data = abi.encode(minRoyaltyIpAccount1);

        vm.expectRevert(Errors.RoyaltyPolicyLS__NotRoyaltyModule.selector);
        royaltyPolicyLS.initPolicy(ipAccount1, parentIpIds, data);
    }

    function test_RoyaltyPolicyLS_initPolicy_revert_InvalidMinRoyalty() public {
        vm.startPrank(address(licensingModule));
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

    function test_RoyaltyPolicyLS_initPolicy_revert_ZeroMinRoyalty() public {
        vm.startPrank(address(licensingModule));
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

    function test_RoyaltyPolicyLS_initPolicy_revert_InvalidRoyaltyStack() public {
        vm.startPrank(address(licensingModule));
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

        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds, data);

        (address splitClone, address claimer, uint32 royaltyStack, uint32 minRoyalty) = royaltyPolicyLS.royaltyData(
            ipAccount1
        );

        assertFalse(splitClone == address(0));
        assertEq(claimer, address(royaltyPolicyLS));
        assertEq(royaltyStack, minRoyaltyIpAccount1);
        assertEq(minRoyalty, minRoyaltyIpAccount1);
    }

    function test_RoyaltyPolicyLS_initPolicy_derivativeIPA() public {
        vm.startPrank(address(licensingModule));
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

        (address splitClone, address claimer, uint32 royaltyStack, uint32 minRoyalty) = royaltyPolicyLS.royaltyData(
            ipAccount2
        );

        assertFalse(splitClone == address(0));
        assertFalse(claimer == address(royaltyPolicyLS));
        assertFalse(claimer == address(0));
        assertEq(royaltyStack, minRoyaltyIpAccount1 + minRoyaltyIpAccount2);
        assertEq(minRoyalty, minRoyaltyIpAccount2);
    }

    function test_RoyaltyPolicyLS_onRoyaltyPayment_NotRoyaltyModule() public {
        vm.expectRevert(Errors.RoyaltyPolicyLS__NotRoyaltyModule.selector);

        royaltyPolicyLS.onRoyaltyPayment(address(1), ipAccount1, address(USDC), 1000 * 10 ** 6);
    }

    function test_RoyaltyPolicyLS_onRoyaltyPayment() public {
        vm.startPrank(address(licensingModule));
        // set root parent royalty policy
        address[] memory parentIpIds1 = new address[](0);
        uint32 minRoyaltyIpAccount1 = 100;
        bytes memory data1 = abi.encode(minRoyaltyIpAccount1);
        royaltyModule.setRoyaltyPolicy(ipAccount1, address(royaltyPolicyLS), parentIpIds1, data1);
        (address splitClone1, , , ) = royaltyPolicyLS.royaltyData(ipAccount1);
        vm.stopPrank();

        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(address(1), royaltyAmount);
        vm.startPrank(address(1));
        USDC.approve(address(royaltyPolicyLS), royaltyAmount);
        vm.stopPrank();

        vm.startPrank(address(royaltyModule));

        uint256 splitClone2USDCBalBefore = USDC.balanceOf(splitClone1);
        uint256 splitMainUSDCBalBefore = USDC.balanceOf(address(1));

        royaltyPolicyLS.onRoyaltyPayment(address(1), ipAccount1, address(USDC), royaltyAmount);

        uint256 splitClone2USDCBalAfter = USDC.balanceOf(splitClone1);
        uint256 splitMainUSDCBalAfter = USDC.balanceOf(address(1));

        assertEq(splitClone2USDCBalAfter - splitClone2USDCBalBefore, royaltyAmount);
        assertEq(splitMainUSDCBalBefore - splitMainUSDCBalAfter, royaltyAmount);
    }

    function test_RoyaltyPolicyLS_distributeFunds() public {
        vm.startPrank(address(licensingModule));
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
        (address splitClone2, address claimer2, , ) = royaltyPolicyLS.royaltyData(ipAccount2);

        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        // Switch the index 0 and 1 if facing `InvalidSplit__AccountsOutOfOrder` error
        accounts[0] = ipAccount2;
        accounts[1] = claimer2;

        uint256 splitClone2USDCBalBefore = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalBefore = USDC.balanceOf(royaltyPolicyLS.LIQUID_SPLIT_MAIN());

        royaltyPolicyLS.distributeFunds(ipAccount2, address(USDC), accounts, address(0));

        uint256 splitClone2USDCBalAfter = USDC.balanceOf(splitClone2);
        uint256 splitMainUSDCBalAfter = USDC.balanceOf(royaltyPolicyLS.LIQUID_SPLIT_MAIN());

        assertApproxEqRel(splitClone2USDCBalBefore - splitClone2USDCBalAfter, royaltyAmount, 0.0001e18);
        assertApproxEqRel(splitMainUSDCBalAfter - splitMainUSDCBalBefore, royaltyAmount, 0.0001e18);
    }

    function test_RoyaltyPolicyLS_claimRoyalties() public {
        vm.startPrank(address(licensingModule));
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
        (address splitClone2, address claimer2, , ) = royaltyPolicyLS.royaltyData(ipAccount2);
        vm.stopPrank();

        // send USDC to 0xSplitClone
        uint256 royaltyAmount = 1000 * 10 ** 6;
        USDC.mint(splitClone2, royaltyAmount);

        address[] memory accounts = new address[](2);
        // Switch the index 0 and 1 if facing `InvalidSplit__AccountsOutOfOrder` error
        accounts[0] = ipAccount2;
        accounts[1] = claimer2;

        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = USDC;

        royaltyPolicyLS.distributeFunds(ipAccount2, address(USDC), accounts, address(0));

        royaltyPolicyLS.claimRoyalties(ipAccount2, 0, tokens);
    }
}
