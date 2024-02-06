// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IModule } from "../../interfaces/modules/base/IModule.sol";

/// @title Tagging module interface
interface ITaggingModule is IModule {
    /// @notice Emitted when a tag is set for an IP
    /// @param tag The tag
    /// @param ipId The IP id
    event TagSet(string tag, address ipId);

    /// @notice Emitted when a tag is removed for an IP
    /// @param tag The tag
    /// @param ipId The IP id
    event TagRemoved(string tag, address ipId);

    /// @notice Sets a tag for an IP
    /// @param tag The tag
    /// @param ipId The IP id
    /// @return added True if the tag was added
    function setTag(string calldata tag, address ipId) external returns (bool added);

    /// @notice Removes a tag for an IP
    /// @param tag The tag
    /// @param ipId The IP id
    /// @return removed True if the tag was removed
    function removeTag(string calldata tag, address ipId) external returns (bool removed);

    /// @notice Checks if an IP is tagged with a specific tag
    /// @param tag The tag
    /// @param ipId The IP id
    /// @return True if the IP is tagged with the tag
    function isTagged(string calldata tag, address ipId) external view returns (bool);

    /// @notice Gets the total number of tags for an IP
    /// @param ipId The IP id
    /// @return The total number of tags for the IP
    function totalTagsForIp(address ipId) external view returns (uint256);

    /// @notice Gets the tag at a specific index for an IP
    /// @param ipId The IP id
    /// @param index The index
    /// @return The tag at the index
    function tagAtIndexForIp(address ipId, uint256 index) external view returns (bytes32);

    /// @notice Gets the tag string at a specific index for an IP
    /// @param ipId The IP id
    /// @param index The index
    /// @return The tag string at the index
    function tagStringAtIndexForIp(address ipId, uint256 index) external view returns (string memory);
}
