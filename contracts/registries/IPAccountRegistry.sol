// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IERC6551Registry } from "lib/reference/src/interfaces/IERC6551Registry.sol";

/// @title IPAccountRegistry
/// @notice This contract is responsible for managing the registration and tracking of IP Accounts.
/// It leverages a public ERC6551 registry to deploy IPAccount contracts.
contract IPAccountRegistry is IIPAccountRegistry {
    address public immutable IP_ACCOUNT_IMPL;
    bytes32 public immutable IP_ACCOUNT_SALT;
    address public immutable ERC6551_PUBLIC_REGISTRY;
    address public immutable ACCESS_CONTROLLER;

    error NonExistIpAccountImpl();

    /// @notice Constructor for the IPAccountRegistry contract.
    /// @param erc6551Registry_ The address of the ERC6551 registry.
    /// @param accessController_ The address of the access controller.
    /// @param ipAccountImpl_ The address of the IP account implementation.
    constructor(address erc6551Registry_, address accessController_, address ipAccountImpl_) {
        if (ipAccountImpl_ == address(0)) revert NonExistIpAccountImpl();
        IP_ACCOUNT_IMPL = ipAccountImpl_;
        IP_ACCOUNT_SALT = bytes32(0);
        ERC6551_PUBLIC_REGISTRY = erc6551Registry_;
        ACCESS_CONTROLLER = accessController_;
    }

    /// @notice Deploys an IPAccount contract with the IPAccount implementation and returns the address of the new IP.
    /// @param chainId_ The chain ID where the IP Account will be created.
    /// @param tokenContract_ The address of the token contract to be associated with the IP Account.
    /// @param tokenId_ The ID of the token to be associated with the IP Account.
    /// @return ipAccountAddress The address of the newly created IP Account.
    function registerIpAccount(
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) external returns (address ipAccountAddress) {
        bytes memory initData = abi.encodeWithSignature("initialize(address)", ACCESS_CONTROLLER);
        ipAccountAddress = IERC6551Registry(ERC6551_PUBLIC_REGISTRY).createAccount(
            IP_ACCOUNT_IMPL,
            IP_ACCOUNT_SALT,
            chainId_,
            tokenContract_,
            tokenId_
        );
        (bool success, bytes memory result) = ipAccountAddress.call(initData);
        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
        emit IPAccountRegistered(ipAccountAddress, IP_ACCOUNT_IMPL, chainId_, tokenContract_, tokenId_);
    }

    /// @notice Returns the IPAccount address for the given NFT token.
    /// @param chainId_ The chain ID where the IP Account is located.
    /// @param tokenContract_ The address of the token contract associated with the IP Account.
    /// @param tokenId_ The ID of the token associated with the IP Account.
    /// @return The address of the IP Account associated with the given NFT token.
    function ipAccount(uint256 chainId_, address tokenContract_, uint256 tokenId_) external view returns (address) {
        return _get6551AccountAddress(chainId_, tokenContract_, tokenId_);
    }

    /// @notice Returns the IPAccount implementation address.
    /// @return The address of the IPAccount implementation.
    function getIPAccountImpl() external view override returns (address) {
        return IP_ACCOUNT_IMPL;
    }

    function _get6551AccountAddress(
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) internal view returns (address) {
        return
            IERC6551Registry(ERC6551_PUBLIC_REGISTRY).account(
                IP_ACCOUNT_IMPL,
                IP_ACCOUNT_SALT,
                chainId_,
                tokenContract_,
                tokenId_
            );
    }
}
