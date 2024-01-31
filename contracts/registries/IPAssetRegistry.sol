// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IMetadataProvider } from "contracts/interfaces/registries/metadata/IMetadataProvider.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IP Asset Registry
/// @notice This contract acts as the source of truth for all IP registered in
///         Story Protocol. An IP is identified by its contract address, token
///         id, and coin type, meaning any NFT may be conceptualized as an IP.
///         Once an IP is registered into the protocol, a corresponding IP
///         asset is generated, which references an IP resolver for metadata
///         attribution and an IP account for protocol authorization.
///         IMPORTANT: The IP account address, besides being used for protocol
///                    auth, is also the canonical IP identifier for the IP NFT.
contract IPAssetRegistry is IIPAssetRegistry, IPAccountRegistry {
    /// @notice Attributes for the IP asset type.
    struct Record {
        // Metadata provider for Story Protocol canonicalized metadata.
        address metadataProvider;
        // IP translator for custom IP asset types.
        address resolver;
    }

    address public immutable DEFAULT_METADATA_PROVIDER;

    /// @notice Tracks the total number of IP assets in existence.
    uint256 public totalSupply = 0;

    /// @dev Maps an IP, identified by its IP ID, to an IP asset.
    mapping(address => Record) internal _records;

    /// @notice Initializes the IP Asset Registry.
    /// @param erc6551Registry The address of the ERC6551 registry.
    /// @param accessController The address of the access controller.
    /// @param ipAccountImpl The address of the IP account implementation.
    /// @param metadataProvider The address of the default metadata provider.
    constructor(
        address accessController,
        address erc6551Registry,
        address ipAccountImpl,
        address metadataProvider
    ) IPAccountRegistry(erc6551Registry, accessController, ipAccountImpl) {
        if (metadataProvider == address(0)) {
            revert Errors.IPAssetRegistry_InvalidMetadataProvider();
        }

        DEFAULT_METADATA_PROVIDER = metadataProvider;
    }

    /// @notice Registers an NFT as an IP, creating a corresponding IP asset.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @param createAccount Whether to create an IP account when registering.
    function register(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address resolverAddr,
        bool createAccount
    ) external returns (address account) {
        address id = ipId(chainId, tokenContract, tokenId);
        if (_records[id].resolver != address(0)) {
            revert Errors.IPAssetRegistry_AlreadyRegistered();
        }

        // This is to emphasize the semantic differences between utilizing the
        // IP account as an identifier versus as an account used for auth.
        account = id;

        if (account.code.length == 0 && createAccount) {
            account = registerIpAccount(chainId, tokenContract, tokenId);
            if (account != id) {
                revert Errors.IPAssetRegistry_InvalidAccount();
            }
        }
        _setResolver(id, resolverAddr);
        _setMetadataProvider(id, DEFAULT_METADATA_PROVIDER);
        totalSupply++;
        emit IPRegistered(id, chainId, tokenContract, tokenId, resolverAddr, DEFAULT_METADATA_PROVIDER);
    }

    /// @notice Sets the resolver for an IP based on its NFT attributes.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @param resolverAddr The address of the resolver being set.
    function setResolver(uint256 chainId, address tokenContract, uint256 tokenId, address resolverAddr) external {
        // only IP owner can set resolver
        if (msg.sender != _getOwner(chainId, tokenContract, tokenId)) {
            revert Errors.IPAssetRegistry_Unauthorized();
        }

        address id = ipId(chainId, tokenContract, tokenId);

        // Resolvers may not be set unless the IP was registered into the protocol.
        if (_records[id].resolver == address(0)) {
            revert Errors.IPAssetRegistry_NotYetRegistered();
        }

        _setResolver(id, resolverAddr);
    }

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return super.ipAccount(chainId, tokenContract, tokenId);
    }

    /// @notice Checks whether an IP was registered based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return Whether the IP was registered into the protocol.
    function isRegistered(address id) external view returns (bool) {
        return _records[id].resolver != address(0);
    }

    /// @notice Checks whether an IP was registered based on its NFT attributes.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @return Whether the NFT was registered into the protocol as IP.
    /// TODO: Deprecate this in favor of solely using IP IDs for registration identification.
    function isRegistered(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (bool) {
        address id = ipId(chainId, tokenContract, tokenId);
        return _records[id].resolver != address(0);
    }

    /// @notice Gets the resolver bound to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return The IP resolver address if registered, else the zero address.
    function resolver(address id) external view returns (address) {
        return _records[id].resolver;
    }

    /// @notice Gets the metadata linked to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return The metadata that was bound to this IP at creation time.
    function metadataProvider(address id) external view returns (address) {
        return _records[id].metadataProvider;
    }

    /// @notice Gets the resolver bound to an IP based on its NFT attributes.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @return The IP resolver address if registered, else the zero address.
    /// TODO: Deprecate this in favor of solely using IP IDs for resolver identification.
    function resolver(uint256 chainId, address tokenContract, uint256 tokenId) external view returns (address) {
        address id = ipId(chainId, tokenContract, tokenId);
        return _records[id].resolver;
    }

    /// @dev Sets the resolver for the specified IP.
    /// @param id The canonical ID of the IP.
    /// @param resolverAddr The address of the resolver being set.
    function _setResolver(address id, address resolverAddr) internal {
        ERC165Checker.supportsInterface(resolverAddr, type(IResolver).interfaceId);
        _records[id].resolver = resolverAddr;
        emit IPResolverSet(id, resolverAddr);
    }

    /// @dev Sets the metadata for the specified IP.
    /// @param id The canonical identifier for the specified IP.
    /// @param provider The metadata provider to associated with the IP.
    function _setMetadataProvider(address id, address provider) internal {
        _records[id].metadataProvider = provider;
        emit MetadataProviderSet(id, provider);
    }

    /// @notice Returns the owner of the of token.
    /// @return The address of the owner.
    function _getOwner(uint256 chainId, address tokenContract, uint256 tokenId) internal view returns (address) {
        if (chainId != block.chainid) return address(0);
        return IERC721(tokenContract).ownerOf(tokenId);
    }
}
