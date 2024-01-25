// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

import { IMetadataProvider } from "contracts/interfaces/registries/metadata/IMetadataProvider.sol";
import { REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IP Record Registry
/// @notice This contract acts as the source of truth for all IP registered in
///         Story Protocol. An IP is identified by its contract address, token
///         id, and coin type, meaning any NFT may be conceptualized as an IP.
///         Once an IP is registered into the protocol, a corresponding IP
///         record is generated, which references an IP resolver for metadata
///         attribution and an IP account for protocol authorization. Only
///         approved registration modules may register IP into this registry.
///         IMPORTANT: The IP account address, besides being used for protocol
///                    auth, is also the canonical IP identifier for the IP NFT.
contract IPRecordRegistry is IIPRecordRegistry {
    /// @notice Attributes for the IP record type.
    struct Record {
        // Metadata provider for Story Protocol canonicalized metadata.
        address metadataProvider;
        // IP translator for custom IP record types.
        address resolver;
    }

    /// @notice Gets the factory contract used for IP account creation.
    IIPAccountRegistry public immutable IP_ACCOUNT_REGISTRY;

    /// @notice Gets the protocol-wide module registry.
    IModuleRegistry public immutable MODULE_REGISTRY;

    /// @notice Tracks the total number of IP records in existence.
    uint256 public totalSupply = 0;

    /// @dev Maps an IP, identified by its IP ID, to an IP record.
    mapping(address => Record) internal _records;

    /// @notice Restricts calls to only originate from a protocol-authorized caller.
    modifier onlyRegistrationModule() {
        if (address(MODULE_REGISTRY.getModule(REGISTRATION_MODULE_KEY)) != msg.sender) {
            revert Errors.IPRecordRegistry_Unauthorized();
        }
        _;
    }

    /// @notice Initializes the IP Record Registry.
    /// @param moduleRegistry The address of the protocol module registry.
    /// @param ipAccountRegistry The address of the IP account registry.
    constructor(address moduleRegistry, address ipAccountRegistry) {
        MODULE_REGISTRY = IModuleRegistry(moduleRegistry);
        IP_ACCOUNT_REGISTRY = IIPAccountRegistry(ipAccountRegistry);
    }

    /// @notice Gets the canonical IP identifier associated with an IP NFT.
    /// @dev This is equivalent to the address of its bound IP account.
    /// @param chainId The chain identifier of where the IP resides.
    /// @param tokenContract The address of the IP.
    /// @param tokenId The token identifier of the IP.
    /// @return The IP's canonical address identifier.
    function ipId(uint256 chainId, address tokenContract, uint256 tokenId) public view returns (address) {
        return IP_ACCOUNT_REGISTRY.ipAccount(chainId, tokenContract, tokenId);
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

    /// @notice Registers an NFT as an IP, creating a corresponding IP record.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @param resolverAddr The address of the resolver to associate with the IP.
    /// @param createAccount Whether to create an IP account when registering.
    /// @param provider The metadata provider to associate with the IP.
    function register(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address resolverAddr,
        bool createAccount,
        address provider
    ) external onlyRegistrationModule returns (address account) {
        address id = ipId(chainId, tokenContract, tokenId);
        if (_records[id].resolver != address(0)) {
            revert Errors.IPRecordRegistry_AlreadyRegistered();
        }

        // This is to emphasize the semantic differences between utilizing the
        // IP account as an identifier versus as an account used for auth.
        account = id;

        if (account.code.length == 0 && createAccount) {
            _createIPAccount(chainId, tokenContract, tokenId);
        }
        _setResolver(id, resolverAddr);
        _setMetadataProvider(id, provider);
        totalSupply++;
        emit IPRegistered(id, chainId, tokenContract, tokenId, resolverAddr, provider);
    }

    /// @notice Creates the IP account for the specified IP.
    /// @custom:note For now, we assume that every IP is uniquely tied to an IP
    ///              account deployed by the IP account registry. However, this
    ///              may change in the future, hence the distinguishing between
    ///              IP accounts as identifiers vs. authentication primitives.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// TODO: Deprecate this in favor of relying on creation via a periphery
    ///       contract or through the IPAccountRegistry directly.
    function createIPAccount(uint256 chainId, address tokenContract, uint256 tokenId) external returns (address) {
        address account = IP_ACCOUNT_REGISTRY.ipAccount(chainId, tokenContract, tokenId);
        // TODO: Finalize disambiguation between IP accounts and IP identifiers.
        if (account.code.length != 0) {
            revert Errors.IPRecordRegistry_IPAccountAlreadyCreated();
        }
        return _createIPAccount(chainId, tokenContract, tokenId);
    }

    /// @notice Sets the underlying metadata provider for an IP asset.
    /// @param id The canonical ID of the IP.
    /// @param provider Address of the metadata provider associated with the IP.
    function setMetadataProvider(
        address id,
        address provider
    ) external onlyRegistrationModule {
        // Metadata may not be set unless the IP was registered into the protocol.
        if (_records[id].resolver == address(0)) {
            revert Errors.IPRecordRegistry_NotYetRegistered();
        }
        _setMetadataProvider(id, provider);
    }

    /// @notice Sets the resolver for an IP based on its NFT attributes.
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    /// @param resolverAddr The address of the resolver being set.
    /// TODO: Deprecate this in favor of relying solely on IP ids for settings
    ///       and instead including this in a periphery contract.
    function setResolver(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        address resolverAddr
    ) external onlyRegistrationModule {
        address id = ipId(chainId, tokenContract, tokenId);
        setResolver(id, resolverAddr);
    }

    /// @notice Sets the resolver for an IP based on its canonical ID.
    /// @param id The canonical ID of the IP.
    /// @param resolverAddr The address of the resolver being set.
    function setResolver(address id, address resolverAddr) public onlyRegistrationModule {
        if (resolverAddr == address(0)) {
            revert Errors.IPRecordRegistry_ResolverInvalid();
        }
        // Resolvers may not be set unless the IP was registered into the protocol.
        if (_records[id].resolver == address(0)) {
            revert Errors.IPRecordRegistry_NotYetRegistered();
        }
        _setResolver(id, resolverAddr);
    }

    /// @dev Creates an IP account for the specified IP (NFT).
    /// @param chainId The chain identifier of where the NFT resides.
    /// @param tokenContract The address of the NFT.
    /// @param tokenId The token identifier of the NFT.
    function _createIPAccount(
        uint256 chainId,
        address tokenContract,
        uint256 tokenId
    ) internal returns (address account) {
        account = IP_ACCOUNT_REGISTRY.registerIpAccount(chainId, tokenContract, tokenId);
        emit IPAccountSet(account, chainId, tokenContract, tokenId);
    }

    /// @dev Sets the resolver for the specified IP.
    /// @param id The canonical identifier for the specified IP.
    /// @param resolverAddr The address of the IP resolver.
    function _setResolver(address id, address resolverAddr) internal {
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
}
