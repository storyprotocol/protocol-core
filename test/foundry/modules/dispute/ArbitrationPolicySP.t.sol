// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC6551AccountLib } from "lib/reference/src/lib/ERC6551AccountLib.sol";
// contracts
import {Errors} from "contracts/lib/Errors.sol";
import {ArbitrationPolicySP} from "contracts/modules/dispute-module/policies/ArbitrationPolicySP.sol";
import { IP } from "contracts/lib/IP.sol";
// test
import { UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/integration/shared/LicenseHelper.sol";
import { MintPaymentPolicyFrameworkManager } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { TestHelper } from "test/utils/TestHelper.sol";

contract TestArbitrationPolicySP is TestHelper {

    address public ipAddr;

    function setUp() public override {
        super.setUp();

        USDC.mint(ipAccount1, 10000 * 10 ** 6);

        // whitelist dispute tag
        disputeModule.whitelistDisputeTags("PLAGIARISM", true);

        // whitelist arbitration policy
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);

        // whitelist arbitration relayer
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), arbitrationRelayer, true);

        _setUMLPolicyFrameworkManager();
        nft = new MockERC721("mock");
        _addUMLPolicy(
            true,
            true,
            UMLPolicyGenericParams({
                policyName: "cheap_flexible", // => uml_cheap_flexible
                attribution: false,
                transferable: true,
                territories: new string[](0),
                distributionChannels: new string[](0)
            }),
            UMLPolicyCommercialParams({
                commercialAttribution: true,
                commercializers: new string[](0),
                commercialRevShare: 10
            }),
            UMLPolicyDerivativeParams({
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativesRevShare: 10
            })
        );


        nft.mintId(deployer, 0);

        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            address(nft),
            0
        );
        vm.label(expectedAddr, string(abi.encodePacked("IPAccount", Strings.toString(0))));

        vm.startPrank(deployer);
        ipAddr = registrationModule.registerRootIp(
            policyIds["uml_cheap_flexible"],
            address(nft),
            0,
            abi.encode(
                IP.MetadataV1({
                    name: "IPAccount1",
                    hash: bytes32("some of the best description"),
                    registrationDate: uint64(block.timestamp),
                    registrant: deployer,
                    uri: "https://example.com/test-ip"
                })
            )
        );
        vm.label(ipAddr, string(abi.encodePacked("IPAccount", Strings.toString(0))));

        // set arbitration policy
        vm.startPrank(ipAddr);
        disputeModule.setArbitrationPolicy(ipAddr, address(arbitrationPolicySP));
        vm.stopPrank();
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
        address caller = ipAccount1;
        vm.startPrank(caller);
        USDC.approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        vm.stopPrank();

        USDC.mint(caller, 10000 * 10 ** 6);

        vm.startPrank(address(disputeModule));

        uint256 userUSDCBalBefore = USDC.balanceOf(caller);
        uint256 arbitrationContractBalBefore = USDC.balanceOf(address(arbitrationPolicySP));

        arbitrationPolicySP.onRaiseDispute(caller, new bytes(0));

        uint256 userUSDCBalAfter = USDC.balanceOf(caller);
        uint256 arbitrationContractBalAfter = USDC.balanceOf(address(arbitrationPolicySP));

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
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = USDC.balanceOf(address(arbitrationPolicySP));

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, true, "");

        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = USDC.balanceOf(address(arbitrationPolicySP));

        assertEq(ipAccount1USDCBalanceAfter - ipAccount1USDCBalanceBefore, ARBITRATION_PRICE);
        assertEq(arbitrationPolicySPUSDCBalanceBefore - arbitrationPolicySPUSDCBalanceAfter, ARBITRATION_PRICE);
    }

    function test_ArbitrationPolicySP_onDisputeJudgement_False() public {
        // raise dispute
        vm.startPrank(ipAccount1);
        IERC20(WETH).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        // set dispute judgement
        uint256 ipAccount1USDCBalanceBefore = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceBefore = USDC.balanceOf(address(arbitrationPolicySP));

        vm.startPrank(arbitrationRelayer);
        disputeModule.setDisputeJudgement(1, false, "");

        uint256 ipAccount1USDCBalanceAfter = USDC.balanceOf(ipAccount1);
        uint256 arbitrationPolicySPUSDCBalanceAfter = USDC.balanceOf(address(arbitrationPolicySP));

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
