// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { IRegistrationModule } from "contracts/interfaces/modules/IRegistrationModule.sol";
import { REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP } from "contracts/lib/IP.sol";
import { BaseModule } from "contracts/modules/BaseModule.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";

/// @title Registration Module
/// @notice The registration module is responsible for registration of IP into
///         the protocol. During registration, this module will register an IP
///         into the protocol, create a resolver, and bind to it any licenses
///         and terms specified by the IP registrant (IP account owner).
contract RegistrationModule is BaseModule, IRegistrationModule {
    /// @notice The metadata resolver used by the registration module.
    IPResolver public resolver;
    ILicensingModule private _LICENSING_MODULE;

    /// @notice Initializes the registration module contract.
    /// @param controller The access controller used for IP authorization.
    /// @param assetRegistry The address of the IP asset registry.
    /// @param licenseRegistry The address of the license module.
    constructor(
        address controller,
        address assetRegistry,
        address licenseRegistry,
        address licensingModule,
        address resolverAddr
    ) BaseModule(controller, assetRegistry, licenseRegistry) {
        resolver = IPResolver(resolverAddr);
        _LICENSING_MODULE = ILicensingModule(licensingModule);
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
    function registerRootIp(
        uint256 policyId,
        address tokenContract,
        uint256 tokenId,
        bytes calldata metadata
    ) external returns (address) {
        // Perform registrant authorization.
        // Check that the caller is authorized to perform the registration.
        // TODO: Perform additional registration authorization logic, allowing
        //       registrants or root-IP creators to specify their own auth logic.
        if (IERC721(tokenContract).ownerOf(tokenId) != msg.sender) {
            revert Errors.RegistrationModule__InvalidOwner();
        }

        // Perform core IP registration and IP account creation.
        address ipId = IP_ASSET_REGISTRY.register(
            block.chainid,
            tokenContract,
            tokenId,
            address(resolver),
            true,
            metadata
        );

        // Perform core IP policy creation.
        if (policyId != 0) {
            // If we know the policy ID, we can register it directly on creation.
            // TODO: return policy index
            _LICENSING_MODULE.addPolicyToIp(ipId, policyId);
        }

        emit RootIPRegistered(msg.sender, ipId, policyId);

        return ipId;
    }

    /// @notice Registers IP derivatives into the protocol.
    /// @param licenseIds The licenses to incorporate for the new IP.
    /// @param tokenContract The address of the NFT bound to the derivative IP.
    /// @param tokenId The token id of the NFT bound to the derivative IP.
    /// @param ipName The name assigned to the new IP.
    /// @param contentHash The content hash of the IP being registered.
    /// @param externalURL An external URI to link to the IP.
    /// TODO: Replace all metadata with a generic bytes parameter type, and do
    ///       encoding on the periphery contract level instead.
    function registerDerivativeIp(
        uint256[] calldata licenseIds,
        address tokenContract,
        uint256 tokenId,
        string memory ipName,
        bytes32 contentHash,
        string calldata externalURL
    ) external {
        // Check that the caller is authorized to perform the registration.
        // TODO: Perform additional registration authorization logic, allowing
        //       registrants or IP creators to specify their own auth logic.
        if (IERC721(tokenContract).ownerOf(tokenId) != msg.sender) {
            revert Errors.RegistrationModule__InvalidOwner();
        }

        bytes memory metadata = abi.encode(
            IP.MetadataV1({
                name: ipName,
                hash: contentHash,
                registrationDate: uint64(block.timestamp),
                registrant: msg.sender,
                uri: externalURL
            })
        );
        address ipId = IP_ASSET_REGISTRY.register(
            block.chainid,
            tokenContract,
            tokenId,
            address(resolver),
            true,
            metadata
        );

        // Perform core IP derivative licensing - the license must be owned by the caller.
        _LICENSING_MODULE.linkIpToParents(licenseIds, ipId, msg.sender);

        emit DerivativeIPRegistered(msg.sender, ipId, licenseIds);
    }

    /// @notice Gets the protocol-wide module identifier for this module.
    function name() public pure override returns (string memory) {
        return REGISTRATION_MODULE_KEY;
    }
}
