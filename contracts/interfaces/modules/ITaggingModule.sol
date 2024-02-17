// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IModule } from "../../interfaces/modules/base/IModule.sol";

/// @title Tagging module interface
interface ITaggingModule is IModule {
    /// @notice Emitted when a tag is set for an IP asset
    /// @param tag The tag value
    /// @param ipId The ID of the IP asset
    event TagSet(string tag, address ipId);

    /// @notice Emitted when a tag is removed for an IP asset
    /// @param tag The tag value
    /// @param ipId The ID of the IP asset
    event TagRemoved(string tag, address ipId);

    /// @notice The maximum number of tag permissions that can be set at once
    function MAX_TAG_PERMISSIONS_AT_ONCE() external view returns (uint256);

    /// @notice Sets a tag on an IP asset
    /// @param tag The tag value
    /// @param ipId The ID of the IP asset
    /// @return added True if the tag was added
    function setTag(string calldata tag, address ipId) external returns (bool added);

    /// @notice Removes a tag from an IP asset
    /// @param tag The tag value
    /// @param ipId The ID of the IP asset
    /// @return removed True if the tag was removed
    function removeTag(string calldata tag, address ipId) external returns (bool removed);

    /// @notice Checks if an IP asset is tagged with a specific tag
    /// @param tag The tag value
    /// @param ipId The ID of the IP asset
    /// @return True if the IP asset is tagged with the tag
    function isTagged(string calldata tag, address ipId) external view returns (bool);

    /// @notice Gets the total number of tags for an IP asset
    /// @param ipId The ID of the IP asset
    /// @return totalTags The total number of tags for the IP asset
    function totalTagsForIp(address ipId) external view returns (uint256);

    /// @notice Gets the tag at a specific index for an IP asset
    /// @dev Tag ordering is not guaranteed, as it's stored in a set
    /// @param ipId The ID of the IP asset
    /// @param index The local index of the tag on the IP asset
    /// @return tagBytes The tag value in bytes
    function tagAtIndexForIp(address ipId, uint256 index) external view returns (bytes32);

    /// @notice Gets the tag string at a specific index for an IP
    /// @dev Tag ordering is not guaranteed, as it's stored in a set
    /// @param ipId The ID of the IP asset
    /// @param index The local index of the tag on the IP asset
    /// @return tagString The tag value casted as string
    function tagStringAtIndexForIp(address ipId, uint256 index) external view returns (string memory);
}
