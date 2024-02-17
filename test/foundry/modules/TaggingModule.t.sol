// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { ShortStringOps } from "../../../contracts/utils/ShortStringOps.sol";

import { BaseTest } from "../utils/BaseTest.t.sol";

contract TaggingModuleTest is BaseTest {
    using ShortStrings for *;

    function setUp() public override {
        super.setUp();
        buildDeployModuleCondition(
            DeployModuleCondition({
                registrationModule: false,
                disputeModule: false,
                royaltyModule: false,
                taggingModule: true,
                licensingModule: false
            })
        );
        deployConditionally();
        postDeploymentSetup();
    }

    function test_TaggingModule_setTag() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
    }

    function test_TaggingModule_removeTag() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.removeTag("test", ipAccount), true);
    }

    function test_TaggingModule_isTagged() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.isTagged("test", ipAccount), true);
    }

    function test_TaggingModule_totalTagsForIP() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.setTag("test-1", ipAccount), true);
        assertEq(taggingModule.setTag("test-2", ipAccount), true);
        assertEq(taggingModule.totalTagsForIp(ipAccount), 3);
    }

    function test_TaggingModule_tagAtIndexForIp() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.setTag("test-1", ipAccount), true);
        assertEq(taggingModule.setTag("test-2", ipAccount), true);
        assertEq(taggingModule.tagAtIndexForIp(ipAccount, 2), ShortStringOps.stringToBytes32("test-2"));
    }

    function test_TaggingModule_tagStringAtIndexForIp() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.setTag("test-1", ipAccount), true);
        assertEq(taggingModule.setTag("test-2", ipAccount), true);
        assertEq(taggingModule.tagStringAtIndexForIp(ipAccount, 2), "test-2");
    }
}
