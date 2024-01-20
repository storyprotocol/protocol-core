// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "contracts/lib/Errors.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";

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

    function test_taggingModule_createRelationType() public {
        taggingModule.createRelationType("test", "src", "dst");
        TaggingModule.RelationType memory relationType = taggingModule.getRelationType("test");
        assertEq(relationType.srcTag, ShortStringOps.stringToBytes32("src"));
        assertEq(relationType.dstTag, ShortStringOps.stringToBytes32("dst"));
    }

    function test_taggingModule_createRelation() public {
        taggingModule.createRelationType("test", "src", "dst");
        address ipAccountSrc = address(1);
        address ipAccountDst = address(2);
        assertEq(taggingModule.setTag("src", ipAccountSrc), true);
        assertEq(taggingModule.setTag("dst", ipAccountDst), true);
        taggingModule.createRelation("test", ipAccountSrc, ipAccountDst);
        assertTrue(taggingModule.relationExists(TaggingModule.Relation("test".toShortString(), ipAccountSrc, ipAccountDst)));
    }

}