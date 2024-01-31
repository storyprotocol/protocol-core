// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
// solhint-disable-next-line max-line-length
import { IMetadataProviderUpgradeable } from "contracts/interfaces/registries/metadata/IMetadataProviderUpgradeable.sol";
import { MetadataProviderV1 } from "contracts/registries/metadata/MetadataProviderV1.sol";
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
        IMetadataProviderUpgradeable metadataProvider;
        address resolver;
    }

    /// @notice Tracks the total number of IP assets in existence.
    uint256 public totalSupply = 0;

    /// @notice Protocol governance administrator of the IP record registry.
    address public owner;

    /// @dev Maps an IP, identified by its IP ID, to an IP record.
    mapping(address => Record) internal _records;

    /// @notice Tracks the current metadata provider used for IP registrations.
    IMetadataProviderUpgradeable internal _metadataProvider;

    /// @notice Ensures only protocol governance owner may call a function.
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Errors.IPAssetRegistry__Unauthorized();
        }
        _;
    }

    /// @notice Initializes the IP Asset Registry.
    /// @param erc6551Registry The address of the ERC6551 registry.
    /// @param accessController The address of the access controller.
    /// @param ipAccountImpl The address of the IP account implementation.
    constructor(
        address accessController,
        address erc6551Registry,
        address ipAccountImpl
    ) IPAccountRegistry(erc6551Registry, accessController, ipAccountImpl) {
        // TODO: Migrate this to a parameterized governance owner address.
        owner = msg.sender;
        _metadataProvider = IMetadataProviderUpgradeable(new MetadataProviderV1(address(this)));
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
        bool createAccount,
        bytes calldata data
    ) external returns (address id) {
        id = ipId(chainId, tokenContract, tokenId);
        if (_records[id].resolver != address(0)) {
            revert Errors.IPAssetRegistry__AlreadyRegistered();
        }

        if (id.code.length == 0 && createAccount && id != registerIpAccount(chainId, tokenContract, tokenId)) {
            revert Errors.IPAssetRegistry__InvalidAccount();
        }
        _setResolver(id, resolverAddr);
        _setMetadata(id, _metadataProvider, data);
        totalSupply++;
        emit IPRegistered(id, chainId, tokenContract, tokenId, resolverAddr, address(_metadataProvider), data);
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

    /// @notice Gets the resolver bound to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return The IP resolver address if registered, else the zero address.
    function resolver(address id) external view returns (address) {
        return _records[id].resolver;
    }

    /// @notice Gets the metadata provider used for new metadata registrations.
    /// @return The address of the metadata provider used for new IP registrations.
    function metadataProvider() external view returns (address) {
        return address(_metadataProvider);
    }

    /// @notice Gets the metadata provider linked to an IP based on its ID.
    /// @param id The canonical identifier for the IP.
    /// @return The metadata provider that was bound to this IP at creation time.
    function metadataProvider(address id) external view returns (address) {
        return address(_records[id].metadataProvider);
    }

    /// @notice Gets the underlying canonical metadata linked to an IP asset.
    /// @param id The canonical ID of the IP asset.
    function metadata(address id) external view returns (bytes memory) {
        if (address(_records[id].metadataProvider) == address(0)) {
            revert Errors.IPAssetRegistry__NotYetRegistered();
        }
        return _records[id].metadataProvider.getMetadata(id);
    }

    /// @notice Sets the provider for storage of new IP metadata, while enabling
    ///         existing IP assets to migrate their metadata to the new provider.
    /// @param newMetadataProvider Address of the new metadata provider contract.
    function setMetadataProvider(address newMetadataProvider) external onlyOwner {
        _metadataProvider.setUpgradeProvider(newMetadataProvider);
        _metadataProvider = IMetadataProviderUpgradeable(newMetadataProvider);
    }

    /// @notice Sets the underlying metadata for an IP asset.
    /// @dev As metadata is immutable but additive, this will only be used when
    ///      an IP migrates from a new provider that introduces new attributes.
    /// @param id The canonical ID of the IP.
    /// @param data Canonical metadata to associate with the IP.
    function setMetadata(address id, address provider, bytes calldata data) external {
        // Metadata is set on registration and immutable thereafter, with new fields
        // only added during a migration to new protocol-approved metadata provider.
        if (address(_records[id].metadataProvider) != msg.sender) {
            revert Errors.IPAssetRegistry__Unauthorized();
        }
        _setMetadata(id, IMetadataProviderUpgradeable(provider), data);
    }

    /// @notice Sets the resolver for an IP based on its canonical ID.
    /// @param id The canonical ID of the IP.
    /// @param resolverAddr The address of the resolver being set.
    function setResolver(address id, address resolverAddr) public {
        if (_records[id].resolver == address(0)) {
            revert Errors.IPAssetRegistry__NotYetRegistered();
        }
        if (msg.sender != IIPAccount(payable(id)).owner()) {
            revert Errors.IPAssetRegistry__Unauthorized();
        }
        _setResolver(id, resolverAddr);
    }

    /// @dev Sets the resolver for the specified IP.
    /// @param id The canonical ID of the IP.
    /// @param resolverAddr The address of the resolver being set.
    function _setResolver(address id, address resolverAddr) internal {
        _records[id].resolver = resolverAddr;
        emit IPResolverSet(id, resolverAddr);
    }

    /// @dev Sets the for the specified IP asset.
    /// @param id The canonical identifier for the specified IP asset.
    /// @param provider The metadata provider hosting the data.
    /// @param data The metadata to set for the IP asset.
    function _setMetadata(address id, IMetadataProviderUpgradeable provider, bytes calldata data) internal {
        _records[id].metadataProvider = provider;
        provider.setMetadata(id, data);
        emit MetadataSet(id, address(provider), data);
    }
}
