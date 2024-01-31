// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { DisputeModule } from "../../contracts/modules/dispute-module/DisputeModule.sol";
import { ArbitrationPolicySP } from "../../contracts/modules/dispute-module/policies/ArbitrationPolicySP.sol";
import { RoyaltyModule } from "../../contracts/modules/royalty-module/RoyaltyModule.sol";
import { RoyaltyPolicyLS } from "../../contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { LSClaimer } from "../../contracts/modules/royalty-module/policies/LSClaimer.sol";
import { MockUSDC } from "../foundry/mocks/MockUSDC.sol";

contract DeployHelper is Test {
    DisputeModule public disputeModule;
    ArbitrationPolicySP public arbitrationPolicySP;
    RoyaltyModule public royaltyModule;
    RoyaltyPolicyLS public royaltyPolicyLS;

    uint256 public constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 USDC

    // USDC
    string public constant USDC_NAME = "USD Coin";
    string public constant USDC_SYMBOL = "USDC";
    uint8 public constant USDC_DECIMALS = 6;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_RICH = 0xcEe284F754E854890e311e3280b767F80797180d;

    // Liquid Split (ETH Mainnet)
    address public constant LIQUID_SPLIT_FACTORY = 0xdEcd8B99b7F763e16141450DAa5EA414B7994831;
    address public constant LIQUID_SPLIT_MAIN = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;

    function deploy() public {
        disputeModule = new DisputeModule();
        arbitrationPolicySP = new ArbitrationPolicySP(address(disputeModule), USDC, ARBITRATION_PRICE);
        royaltyModule = new RoyaltyModule();
        royaltyPolicyLS = new RoyaltyPolicyLS(address(royaltyModule), address(1), LIQUID_SPLIT_FACTORY, LIQUID_SPLIT_MAIN);

        // if code at USDC is zero, then deploy ERC20 to that address
        // and also deploy other RoyaltyModule dependencies
        /*         if (USDC.code.length == 0) {
            bytes memory code = vm.getDeployedCode("MockUSDC.sol:MockUSDC");
            vm.etch(USDC, code);
            vm.label(USDC, "USDC");
            // assertEq(USDC.code, code);
            MockUSDC(USDC).mint(USDC_RICH, 100_000_000 ether);
        } */

        vm.label(address(disputeModule), "disputeModule");
        vm.label(address(arbitrationPolicySP), "arbitrationPolicySP");
        vm.label(address(royaltyModule), "royaltyModule");
        vm.label(address(royaltyPolicyLS), "royaltyPolicyLS");

        // console2.logBytes(0xdEcd8B99b7F763e16141450DAa5EA414B7994831.code);
    }
}
