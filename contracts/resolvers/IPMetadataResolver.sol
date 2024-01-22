// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { ResolverBase } from "./ResolverBase.sol";
import { BaseModule } from "contracts/modules/BaseModule.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { IIPMetadataResolver } from "contracts/interfaces/resolvers/IIPMetadataResolver.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP } from "contracts/lib/IP.sol";
import { METADATA_RESOLVER_MODULE_KEY } from "contracts/lib/modules/Module.sol";

/// @title IP Metadata Resolver
/// @notice Canonical IP resolver contract used for Story Protocol. This will
///         likely change to a separate contract that extends IPMetadataResolver
///         in the near future.
contract IPMetadataResolver is IIPMetadataResolver, ResolverBase {
    /// @dev Maps IP to their metadata records based on their canonical IDs.
    mapping(address => IP.MetadataRecord) public _records;

    /// @notice Initializes the IP metadata resolver.
    /// @param accessController The access controller used for IP authorization.
    /// @param ipRecordRegistry The address of the IP record registry.
    /// @param ipAccountRegistry The address of the IP account registry.
    /// @param licenseRegistry The address of the license registry.
    constructor(
        address accessController,
        address ipRecordRegistry,
        address ipAccountRegistry,
        address licenseRegistry
    ) ResolverBase(accessController, ipRecordRegistry, ipAccountRegistry, licenseRegistry) {}

    /// @notice Fetches all metadata associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    function metadata(address ipId) public view returns (IP.Metadata memory) {
        IP.MetadataRecord memory record = _records[ipId];
        return
            IP.Metadata({
                owner: owner(ipId),
                name: record.name,
                description: record.description,
                hash: record.hash,
                registrationDate: record.registrationDate,
                registrant: record.registrant,
                uri: uri(ipId)
            });
    }

    /// @notice Fetches the canonical name associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    function name(address ipId) external view returns (string memory) {
        return _records[ipId].name;
    }

    /// @notice Fetches the description associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @return The string descriptor of the IP.
    function description(address ipId) external view returns (string memory) {
        return _records[ipId].description;
    }

    /// @notice Fetches the keccak-256 hash associated with the specified IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @return The bytes32 content hash of the IP.
    function hash(address ipId) external view returns (bytes32) {
        return _records[ipId].hash;
    }

    /// @notice Fetches the date of registration of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function registrationDate(address ipId) external view returns (uint64) {
        return _records[ipId].registrationDate;
    }

    /// @notice Fetches the initial registrant of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function registrant(address ipId) external view returns (address) {
        return _records[ipId].registrant;
    }

    /// @notice Fetches the current owner of the IP.
    /// @param ipId The canonical ID of the specified IP.
    function owner(address ipId) public view returns (address) {
        if (!IP_RECORD_REGISTRY.isRegistered(ipId)) {
            return address(0);
        }
        return IIPAccount(payable(ipId)).owner();
    }

    /// @notice Fetches an IP owner defined URI associated with the IP.
    /// @param ipId The canonical ID of the specified IP.
    function uri(address ipId) public view returns (string memory) {
        if (!IP_RECORD_REGISTRY.isRegistered(ipId)) {
            return "";
        }

        IP.MetadataRecord memory record = _records[ipId];
        string memory ipUri = record.uri;

        if (bytes(ipUri).length > 0) {
            return ipUri;
        }

        return _defaultTokenURI(ipId, record);
    }

    /// @notice Sets metadata associated with an IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param newMetadata The new metadata to set for the IP.
    function setMetadata(address ipId, IP.MetadataRecord calldata newMetadata) external onlyAuthorized(ipId) {
        _records[ipId] = newMetadata;
    }

    /// @notice Sets the name associated with an IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param newName The new string name to associate with the IP.
    function setName(address ipId, string calldata newName) external onlyAuthorized(ipId) {
        _records[ipId].name = newName;
    }

    /// @notice Sets the description associated with an IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param newDescription The string description to associate with the IP.
    function setDescription(address ipId, string calldata newDescription) external onlyAuthorized(ipId) {
        _records[ipId].description = newDescription;
    }

    /// @notice Sets the keccak-256 hash associated with an IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param newHash The keccak-256 hash to associate with the IP.
    function setHash(address ipId, bytes32 newHash) external onlyAuthorized(ipId) {
        _records[ipId].hash = newHash;
    }

    /// @notice Sets an IP owner defined URI to associate with the IP.
    /// @param ipId The canonical ID of the specified IP.
    /// @param newURI The new token URI to set for the IP.
    function setURI(address ipId, string calldata newURI) external onlyAuthorized(ipId) {
        _records[ipId].uri = newURI;
    }

    /// @notice Checks whether the resolver interface is supported.
    /// @param id The resolver interface identifier.
    /// @return Whether the resolver interface is supported.
    function supportsInterface(bytes4 id) public view virtual override(IResolver, ResolverBase) returns (bool) {
        return id == type(IIPMetadataResolver).interfaceId || super.supportsInterface(id);
    }

    /// @notice Gets the protocol-wide module identifier for this module.
    function name() public pure override(BaseModule, IModule) returns (string memory) {
        return METADATA_RESOLVER_MODULE_KEY;
    }

    /// @dev Internal function for generating a default IP URI if not provided.
    /// @param ipId The canonical ID of the specified IP.
    /// @param record The IP record associated with the IP.
    function _defaultTokenURI(address ipId, IP.MetadataRecord memory record) internal view returns (string memory) {
        string memory baseJson = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"name": "IP Asset #',
                Strings.toHexString(ipId),
                '", "description": "',
                record.description,
                '", "attributes": ['
            )
            /* solhint-enable */
        );

        string memory ipAttributes = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"trait_type": "Name", "value": "',
                record.name,
                '"},'
                '{"trait_type": "Owner", "value": "',
                Strings.toHexString(uint160(owner(ipId)), 20),
                '"},'
                '{"trait_type": "Registrant", "value": "',
                Strings.toHexString(uint160(record.registrant), 20),
                '"},',
                '{"trait_type": "Hash", "value": "',
                Strings.toHexString(uint256(record.hash), 32),
                '"},',
                '{"trait_type": "Registration Date", "value": "',
                Strings.toString(record.registrationDate),
                '"}'
            )
            /* solhint-enable */
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(string(abi.encodePacked(baseJson, ipAttributes, "]}"))))
                )
            );
    }
}
