// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf

pragma solidity ^0.8.23;

import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { ShortStringOps } from "../../utils/ShortStringOps.sol";
import { ITaggingModule } from "../../interfaces/modules/ITaggingModule.sol";
import { TAGGING_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";

contract TaggingModule is BaseModule, ITaggingModule {
    using ERC165Checker for address;
    using ShortStrings for *;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    string public constant override name = TAGGING_MODULE_KEY;

    /// @notice The maximum number of tag permissions that can be set at once
    uint256 public constant MAX_TAG_PERMISSIONS_AT_ONCE = 300;

    /// @dev The tags for IP assets
    mapping(address => EnumerableSet.Bytes32Set) private _tagsForIpIds;

    /// @notice Sets a tag on an IP asset
    /// @param tag The tag value
    /// @param ipId The ID of the IP asset
    /// @return added True if the tag was added
    function setTag(string calldata tag, address ipId) external returns (bool added) {
        // TODO: access control
        // TODO: emit
        emit TagSet(tag, ipId);
        return _tagsForIpIds[ipId].add(ShortStringOps.stringToBytes32(tag));
    }

    /// @notice Removes a tag from an IP asset
    /// @param tag The tag value
    /// @param ipId The ID of the IP asset
    /// @return removed True if the tag was removed
    function removeTag(string calldata tag, address ipId) external returns (bool removed) {
        // TODO: access control
        emit TagRemoved(tag, ipId);
        return _tagsForIpIds[ipId].remove(ShortStringOps.stringToBytes32(tag));
    }

    /// @notice Checks if an IP asset is tagged with a specific tag
    /// @param tag The tag value
    /// @param ipId The ID of the IP asset
    /// @return True if the IP asset is tagged with the tag
    function isTagged(string calldata tag, address ipId) external view returns (bool) {
        return _tagsForIpIds[ipId].contains(ShortStringOps.stringToBytes32(tag));
    }

    /// @notice Gets the total number of tags for an IP asset
    /// @param ipId The ID of the IP asset
    /// @return totalTags The total number of tags for the IP asset
    function totalTagsForIp(address ipId) external view returns (uint256) {
        return _tagsForIpIds[ipId].length();
    }

    /// @notice Gets the tag at a specific index for an IP asset
    /// @dev Tag ordering is not guaranteed, as it's stored in a set
    /// @param ipId The ID of the IP asset
    /// @param index The local index of the tag on the IP asset
    /// @return tagBytes The tag value in bytes
    function tagAtIndexForIp(address ipId, uint256 index) external view returns (bytes32) {
        // WARNING: tag ordering not guaranteed (since they can be removed)
        return _tagsForIpIds[ipId].at(index);
    }

    /// @notice Gets the tag string at a specific index for an IP
    /// @dev Tag ordering is not guaranteed, as it's stored in a set
    /// @param ipId The ID of the IP asset
    /// @param index The local index of the tag on the IP asset
    /// @return tagString The tag value casted as string
    function tagStringAtIndexForIp(address ipId, uint256 index) external view returns (string memory) {
        // WARNING: tag ordering not guaranteed (since they can be removed)
        return ShortString.wrap(_tagsForIpIds[ipId].at(index)).toString();
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(ITaggingModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
