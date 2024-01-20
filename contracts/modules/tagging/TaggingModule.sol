// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf

pragma solidity ^0.8.21;

import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";

contract TaggingModule is IModule {
    using ShortStrings for *;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 constant MAX_TAG_PERMISSIONS_AT_ONCE = 300;

    struct RelationType {
        bytes32 srcTag;
        bytes32 dstTag;
    }

    struct Relation {
        /// Relationship type name id
        ShortString relTypeName;
        /// Source address
        address srcIpId;
        /// Destination address
        address dstIpId;
    }
    string public name = "TaggingModule";

    mapping(address => EnumerableSet.Bytes32Set) private _tagsForIpIds;
    mapping(ShortString => RelationType) private _relationTypes;
    mapping(bytes32 => Relation) private _relations;

    function createRelationType(string memory relTypeName, string calldata srcTag, string calldata dstTag) external {
        if (ShortStringOps.stringToBytes32(relTypeName) == bytes32(0)) {
            revert Errors.TaggingModule__InvalidRelationTypeName();
        }
        if (_relationTypes[relTypeName.toShortString()].srcTag != bytes32(0)) {
            revert Errors.TaggingModule__RelationTypeAlreadyExists();
        }
        _relationTypes[relTypeName.toShortString()] = RelationType(
            ShortStringOps.stringToBytes32(srcTag),
            ShortStringOps.stringToBytes32(dstTag)
        );
    }

    function getRelationType(string calldata relTypeName) external view returns (RelationType memory) {
        return _relationTypes[relTypeName.toShortString()];
    }

    function createRelation(string calldata relTypeName, address srcIpId, address dstIpId) external {
        RelationType memory relType = _relationTypes[relTypeName.toShortString()];
        if (relType.srcTag == bytes32(0)) {
            revert Errors.TaggingModule__RelationTypeDoesNotExist();
        }
        if (!_tagsForIpIds[srcIpId].contains(relType.srcTag)) {
            revert Errors.TaggingModule__SrcIpIdDoesNotHaveSrcTag();
        }
        if (!_tagsForIpIds[dstIpId].contains(relType.dstTag)) {
            revert Errors.TaggingModule__DstIpIdDoesNotHaveDstTag();
        }
        Relation memory relation = Relation(
            relTypeName.toShortString(),
            srcIpId,
            dstIpId
        );
        _relations[keccak256(abi.encode(relation))] = relation;
    }

    function relationExists(
        Relation calldata relation
    ) external view virtual returns (bool) {
        return _relations[keccak256(abi.encode(relation))].srcIpId != address(0);
    }

    function setTag(string calldata tag, address ipId) external returns (bool added) {
        // TODO: access control
        // TODO: emit
        return _tagsForIpIds[ipId].add(ShortStringOps.stringToBytes32(tag));
    }

    function removeTag(string calldata tag, address ipId) external returns (bool removed) {
        // TODO: access control
        return _tagsForIpIds[ipId].remove(ShortStringOps.stringToBytes32(tag));
    }

    function isTagged(string calldata tag, address ipId) external view returns (bool) {
        return _tagsForIpIds[ipId].contains(ShortStringOps.stringToBytes32(tag));
    }

    function totalTagsForIp(address ipId) external view returns (uint256) {
        return _tagsForIpIds[ipId].length();
    }

    function tagAtIndexForIp(address ipId, uint256 index) external view returns (bytes32) {
        // WARNING: tag ordering not guaranteed (since they can be removed)
        return _tagsForIpIds[ipId].at(index);
    }

    function tagStringAtIndexForIp(address ipId, uint256 index) external view returns (string memory) {
        // WARNING: tag ordering not guaranteed (since they can be removed)
        return ShortString.wrap(_tagsForIpIds[ipId].at(index)).toString();
    }

}
