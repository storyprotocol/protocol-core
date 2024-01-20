// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract TaggingModule {
    using ShortStrings for *;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 constant MAX_TAG_PERMISSIONS_AT_ONCE = 300; 

    struct RelationType {
        // src tag
        // dst tag
    }

    
    mapping(bytes32 => EnumerableSet.AddressSet) private _tagPermissions;
    mapping(address => EnumerableSet.Bytes32Set) private _tagsForIpIds;

    function setTaggingPermissions(string calldata tag, address[] memory ipIds) {
        // TODO: emit
        for(uint256 i = 0; i < ipIds.length; i++) {
            if (ipIds[i] == address(0)) revert 
            _tagPermissions[ShortStringOps.stringToBytes32(tag)].add(ipIds[i]);
        }
    }

    function setTag(string calldata tag, address ipId) returns (bool added) {
        // TODO: access control
        // TODO: emit
        return _tagsForIpIds[ipId].add(ShortStringOps.stringToBytes32(tag));
    }

    function removeTag(string calldata tag, address ipId) returns (bool removed) {
        // TODO: access control
        return _tagsForIpIds[ipId].remove(ShortStringOps.stringToBytes32(tag));
    }

    function isTagged(string calldata tag, address ipId) returns (bool) {
        return _tagsForIpIds[ipId].contains(tag);
    }

    function totalTagsForIp(address ipId) returns (uint256) {
        return _tagsForIpIds[ipId].length;
    }

    function tagAtIndexForIp(address ipId, uint256 index) returns (bytes32) {
        // WARNING: tag ordering not guaranteed (since they can be removed)
        return _tagsForIpIds[ipId].at(index);
    }

    function tagStringAtIndexForIp(address ipId, uint256 index) returns (string memory) {
        // WARNING: tag ordering not guaranteed (since they can be removed)
        return ShortString.wrap(_tagsForIpIds[ipId].at(index)).toString();
    }

}
