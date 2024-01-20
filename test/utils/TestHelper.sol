// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {DeployHelper} from "./DeployHelper.sol";

contract TestHelper is Test, DeployHelper {
    uint256 internal constant accountA = 1;
    uint256 internal constant accountB = 2;
    uint256 internal constant accountC = 3;
    uint256 internal constant accountD = 4;
    uint256 internal constant accountE = 5;
    uint256 internal constant accountF = 6;
    uint256 internal constant accountG = 7;

    address internal deployer;
    address internal governance;
    address internal arbitrationRelayer;
    address internal ipAccount1;
    address internal ipAccount2;
    address internal ipAccount3;
    address internal ipAccount4;

    function setUp() public virtual {
        deployer = vm.addr(accountA);
        governance = vm.addr(accountB);
        arbitrationRelayer = vm.addr(accountC);
        ipAccount1 = vm.addr(accountD);
        ipAccount2 = vm.addr(accountE);
        ipAccount3 = vm.addr(accountF);
        ipAccount4 = vm.addr(accountG);

        deploy();

        vm.label(deployer, "deployer");
        vm.label(governance, "governance");
        vm.label(arbitrationRelayer, "arbitrationRelayer");
        vm.label(ipAccount1, "ipAccount1");
        vm.label(ipAccount2, "ipAccount2");
        vm.label(ipAccount3, "ipAccount3");
        vm.label(ipAccount4, "ipAccount4");
    }
}
