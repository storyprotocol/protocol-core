// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface ITaggingModule {
    event TagSet(string tag, address ipId);

    event TagRemoved(string tag, address ipId);
}
