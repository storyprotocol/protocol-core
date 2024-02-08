// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";

contract TaggingModuleTest is Test {
    using ShortStrings for *;
    TaggingModule public taggingModule;

    function setUp() public {
        taggingModule = new TaggingModule();
    }

    function test_taggingModule_setTag() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
    }

    function test_taggingModule_removeTag() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.removeTag("test", ipAccount), true);
    }

    function test_taggingModule_isTagged() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.isTagged("test", ipAccount), true);
    }

    function test_taggingModule_totalTagsForIP() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.setTag("test-1", ipAccount), true);
        assertEq(taggingModule.setTag("test-2", ipAccount), true);
        assertEq(taggingModule.totalTagsForIp(ipAccount), 3);
    }

    function test_taggingModule_tagAtIndexForIp() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.setTag("test-1", ipAccount), true);
        assertEq(taggingModule.setTag("test-2", ipAccount), true);
        assertEq(taggingModule.tagAtIndexForIp(ipAccount, 2), ShortStringOps.stringToBytes32("test-2"));
    }

    function test_taggingModule_tagStringAtIndexForIp() public {
        address ipAccount = address(1);
        assertEq(taggingModule.setTag("test", ipAccount), true);
        assertEq(taggingModule.setTag("test-1", ipAccount), true);
        assertEq(taggingModule.setTag("test-2", ipAccount), true);
        assertEq(taggingModule.tagStringAtIndexForIp(ipAccount, 2), "test-2");
    }
}
