// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

interface IModuleRegistry {
    function registerModule(string memory name, address moduleAddress) external;

    function getModule(
        string memory name,
        address account
    ) external view returns (address);
}
