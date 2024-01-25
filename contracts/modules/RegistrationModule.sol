// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IPResolver} from "contracts/resolvers/IPResolver.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { IRegistrationModule } from "contracts/interfaces/modules/IRegistrationModule.sol";
import { REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP } from "contracts/lib/IP.sol";
import { BaseModule } from "contracts/modules/BaseModule.sol";

/// @title Registration Module
/// @notice The registration module is responsible for registration of IP into
///         the protocol. During registration, this module will register an IP
///         into the protocol, create a resolver, and bind to it any licenses
///         and terms specified by the IP registrant (IP account owner).
contract RegistrationModule is BaseModule, IRegistrationModule {

    /// @notice The metadata resolver used by the registration module.
    IPResolver public resolver;

    /// @notice Metadata storage provider contract.
    IPMetadataProvider public metadataProvider;

    /// @notice Initializes the registration module contract.
    /// @param controller The access controller used for IP authorization.
    /// @param recordRegistry The address of the IP record registry.
    /// @param accountRegistry The address of the IP account registry.
    /// @param licenseRegistry The address of the license registry.
    /// @param resolverAddr The address of the IP metadata resolver.
    constructor(
        address controller,
        address recordRegistry,
        address accountRegistry,
        address licenseRegistry,
        address resolverAddr,
        address metadataProviderAddr
    ) BaseModule(controller, recordRegistry, accountRegistry, licenseRegistry) {
        metadataProvider = IPMetadataProvider(metadataProviderAddr);
        resolver = IPResolver(resolverAddr);
    }

    /// @notice Registers a root-level IP into the protocol. Root-level IPs can
    ///         be thought of as organizational hubs for encapsulating policies
    ///         that actual IPs can use to register through. As such, a
    ///         root-level IP is not an actual IP, but a container for IP policy
    ///         management for their child IP assets.
    /// TODO: Rethink the semantics behind "root-level IPs" vs. "normal IPs".
    /// TODO: Update function parameters to utilize a struct instead.
    /// TODO: Revisit requiring binding an existing NFT to a "root-level IP".
    ///       If root-level IPs are an organizational primitive, why require NFTs?
    /// TODO: Change to a different resolver optimized for root IP metadata.
    /// @param policyId The policy that identifies the licensing terms of the IP.
    /// @param tokenContract The address of the NFT bound to the root-level IP.
    /// @param tokenId The token id of the NFT bound to the root-level IP.
    function registerRootIp(uint256 policyId, address tokenContract, uint256 tokenId) external returns (address) {
        // Perform registrant authorization.
        // Check that the caller is authorized to perform the registration.
        // TODO: Perform additional registration authorization logic, allowing
        //       registrants or root-IP creators to specify their own auth logic.
        if (IERC721(tokenContract).ownerOf(tokenId) != msg.sender) {
            revert Errors.RegistrationModule__InvalidOwner();
        }

        // Perform core IP registration and IP account creation.
        address ipId = IP_RECORD_REGISTRY.register(block.chainid, tokenContract, tokenId, address(resolver), true, address(metadataProvider));

        // Perform core IP policy creation.
        if (policyId != 0) {
            // If we know the policy ID, we can register it directly on creation.
            // TODO: return policy index
            LICENSE_REGISTRY.addPolicyToIp(ipId, policyId);
        }

        emit RootIPRegistered(msg.sender, ipId, policyId);

        return ipId;
    }

    /// @notice Registers an IP derivative into the protocol.
    /// @param licenseId The license to incorporate for the new IP.
    /// @param tokenContract The address of the NFT bound to the derivative IP.
    /// @param tokenId The token id of the NFT bound to the derivative IP.
    /// @param ipName The name assigned to the new IP.
    /// @param ipDescription A string description to assign to the IP.
    /// @param contentHash The content hash of the IP being registered.
    /// @param externalURL An external URI to link to the IP.
    /// TODO: Replace all metadata with a generic bytes parameter type, and do
    ///       encoding on the periphery contract level instead.
    function registerDerivativeIp(
        uint256 licenseId,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        string memory ipDescription,
        bytes32 contentHash,
        string calldata externalURL
    ) external {
        // Check that the caller is authorized to perform the registration.
        // TODO: Perform additional registration authorization logic, allowing
        //       registrants or IP creators to specify their own auth logic.
        if (IERC721(tokenContract).ownerOf(tokenId) != msg.sender) {
            revert Errors.RegistrationModule__InvalidOwner();
        }

        address ipId = IP_RECORD_REGISTRY.register(block.chainid, tokenContract, tokenId, address(resolver), true, address(metadataProvider));
        // ACCESS_CONTROLLER.setPermission(
        //     ipId,
        //     address(this),
        //     address(resolver),
        //     IPResolver.setMetadata.selector,
        //     1
        // );

        // Perform core IP registration and IP account creation.
        bytes memory metadata = abi.encode(
            IP.Metadata({
                name: ipName,
                hash: contentHash,
                registrationDate: uint64(block.timestamp),
                registrant: msg.sender,
                uri: externalURL
            })
        );
        metadataProvider.setMetadata(ipId, metadata);

        // Perform core IP derivative licensing - the license must be owned by the caller.
        // TODO: return resulting policy index
        LICENSE_REGISTRY.linkIpToParent(licenseId, ipId, msg.sender);

        emit DerivativeIPRegistered(msg.sender, ipId, licenseId);
    }

    /// @notice Gets the protocol-wide module identifier for this module.
    function name() public pure override returns (string memory) {
        return REGISTRATION_MODULE_KEY;
    }
}
