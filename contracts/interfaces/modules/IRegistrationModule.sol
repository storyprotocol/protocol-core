// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IRegistrationModule {
    event RootIPRegistered(address indexed caller, address indexed ipId, uint256 indexed policyId);

    event DerivativeIPRegistered(address indexed caller, address indexed ipId, uint256 licenseId);

    function registerRootIp(uint256 policyId, address tokenContract, uint256 tokenId) external returns (address);

    function registerDerivativeIp(
        uint256 licenseId,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        string memory ipDescription,
        bytes32 hash
    ) external;
}
