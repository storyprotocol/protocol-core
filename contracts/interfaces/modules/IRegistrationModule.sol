// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IRegistrationModule {
    event RootIPRegistered(address indexed caller, address indexed ipId, uint256 indexed policyId);

    event DerivativeIPRegistered(address indexed caller, address indexed ipId, uint256[] licenseIds);

    function registerRootIp(
        uint256 policyId,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 hash,
        string calldata externalURL
    ) external returns (address);

    function registerDerivativeIp(
        uint256[] calldata licenseIds,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 hash,
        string calldata externalURL,
        uint32 minRoyalty
    ) external;
}
