// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title Interface for IP Account Registry
/// @notice This interface manages the registration and tracking of IP Accounts
interface IIPAccountRegistry {
    /// @notice Event emitted when a new IP Account is created
    /// @param account The address of the new IP Account
    /// @param implementation The address of the IP Account implementation
    /// @param chainId The chain ID where the token contract deployed
    /// @param tokenContract The address of the token contract associated with the IP Account
    /// @param tokenId The ID of the token associated with the IP Account
    event IPAccountRegistered(
        address indexed account,
        address indexed implementation,
        uint256 indexed chainId,
        address tokenContract,
        uint256 tokenId
    );

    /// @notice Deploys an IPAccount contract with the IPAccount implementation and returns the address of the new IP
    /// @dev The IPAccount deployment deltegates to public ERC6551 Registry
    /// @param chainId_ The chain ID where  the token contract deployed
    /// @param tokenContract_ The address of the token contract to be associated with the IP Account
    /// @param tokenId_ The ID of the token to be associated with the IP Account
    /// @return The address of the newly created IP Account    
    function registerIpAccount(
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) external returns (address);

    /// @notice Returns the IPAccount address for the given NFT token
    /// @param chainId_ The chain ID where  the token contract deployed
    /// @param tokenContract_ The address of the token contract associated with the IP Account
    /// @param tokenId_ The ID of the token associated with the IP Account
    /// @return The address of the IP Account associated with the given NFT token
    function ipAccount(
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_
    ) external view returns (address);


    /// @notice Returns the IPAccount implementation address
    /// @return The address of the IPAccount implementation
    function getIPAccountImpl() external view returns (address);
}
