// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";

/// @title Interface for IP Account Registry
/// @notice This interface manages the registration and tracking of IP Accounts
interface IIPAssetRegistry is IIPAccountRegistry {
    /// @notice Emits when an IP is officially registered into the protocol.
    /// @param ipId The canonical identifier for the IP.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @param resolver The address of the resolver linked to the IP.
    /// @param provider The address of the metadata provider linked to the IP.
    event IPRegistered(
        address ipId,
        uint256 indexed chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        address resolver,
        address provider
    );

    /// @notice Emits when an IP resolver is bound to an IP.
    /// @param ipId The canonical identifier of the specified IP.
    /// @param resolver The address of the new resolver bound to the IP.
    event IPResolverSet(address ipId, address resolver);

    /// @notice Emits when a metadata provider is set for an IP.
    /// @param ipId The canonical identifier of the specified IP.
    /// @param metadataProvider Address of the metadata provider associated with the IP.
    event MetadataProviderSet(address ipId, address metadataProvider);

    /// @notice Registers an NFT as IP, creating a corresponding IP asset.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @param resolverAddr The address of the resolver to associate with the IP.
    /// @param createAccount Whether to create an IP account in the process.
    function register(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address resolverAddr,
        bool createAccount
    ) external returns (address);

    /// @notice Sets the resolver for an IP based on its NFT attributes.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    function setResolver(uint256 chainId, address tokenContract, uint256 tokenId, address resolver) external;

    /// @notice Gets the canonical IP identifier associated with an IP (NFT).
    /// @dev This is the same as the address of the IP account bound to the IP.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return The address of the associated IP account.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (address);

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool);

    /// @notice Retrieves whether or not an IP was registered.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return Whether the IP was registered into the protocol.
    function isRegistered(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (bool);

    /// @notice Gets the resolver bound to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return The IP resolver address if registered, else the zero address.
    function resolver(address id) external view returns (address);

    /// @notice Gets the resolver bound to an IP based on its NFT attributes.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return The IP resolver address if registered, else the zero address.
    function resolver(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (address);

    /// @notice Gets the metadata provider linked to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return The metadata that was bound to this IP at creation time.
    function metadataProvider(address id) external view returns (address);
}
