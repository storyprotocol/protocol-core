// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC6551Registry {

    /// @notice Emits when a new ERC6551 account is created.
    event AccountCreated(
        address account,
        address indexed implementation,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 salt
    );

    /// @notice Creates a new token-bound account for an NFT.
    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 seed,
        bytes calldata initData
    ) external returns (address);

    /// @notice Retrieves the token-bound account address for an NFT.
    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view returns (address);
}
