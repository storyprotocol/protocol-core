// // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

// external
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// contracts
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { IUMLPolicyFrameworkManager, UMLPolicy } from "contracts/interfaces/licensing/IUMLPolicyFrameworkManager.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/licensing/IPolicyFrameworkManager.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { LicensorApprovalChecker } from "contracts/modules/licensing/parameter-helpers/LicensorApprovalChecker.sol";

/// @title UMLPolicyFrameworkManager
/// @notice This is the UML Policy Framework Manager, which implements the UML Policy Framework
/// logic for encoding and decoding UML policies into the LicenseRegistry and verifying
/// the licensing parameters for linking, minting, and transferring.
contract UMLPolicyFrameworkManager is
    IUMLPolicyFrameworkManager,
    BasePolicyFrameworkManager,
    ILinkParamVerifier,
    IMintParamVerifier,
    ITransferParamVerifier,
    LicensorApprovalChecker
{
    IRoyaltyModule public immutable ROYALTY_MODULE;
    IRoyaltyPolicy public immutable ROYALTY_POLICY_LS;

    constructor(
        address accessController,
        address licRegistry,
        address royaltyModule,
        address royaltyPolicyLS,
        string memory name_,
        string memory licenseUrl_
    ) BasePolicyFrameworkManager(licRegistry, name_, licenseUrl_) LicensorApprovalChecker(accessController) {
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        ROYALTY_POLICY_LS = IRoyaltyPolicy(royaltyPolicyLS);
    }

    function licenseRegistry()
        external
        view
        override(BasePolicyFrameworkManager, IPolicyFrameworkManager)
        returns (address)
    {
        return address(LICENSE_REGISTRY);
    }

    /// @notice Re a new policy to the registry
    /// @dev Must encode the policy into bytes to be stored in the LicenseRegistry
    /// @param umlPolicy UMLPolicy compliant licensing term values
    function registerPolicy(UMLPolicy calldata umlPolicy) external returns (uint256 policyId) {
        _verifyComercialUse(umlPolicy);
        _verifyDerivatives(umlPolicy);
        // No need to emit here, as the LicenseRegistry will emit the event
        return LICENSE_REGISTRY.registerPolicy(abi.encode(umlPolicy));
    }

    /// Called by licenseRegistry to verify policy parameters for linking an IP
    /// with the licensor's IP ID
    /// @param licenseId the ID of the license
    /// @param ipId the IP ID of the IP being linked
    /// @param policyData the licensing policy to verify
    function verifyLink(
        uint256 licenseId,
        address, // caller
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external override onlyLicenseRegistry returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        bool linkingOK = true;
        // If the policy defines commercial revenue sharing, call the royalty module
        // to set it for the licensor
        if (policy.commercialRevShare > 0) {
            // RoyaltyModule.setRevShare()
        }
        // If the policy defines derivative revenue sharing, call the royalty module
        // to set it for the licensor in future derivatives
        if (policy.derivativesRevShare > 0) {
            // RoyaltyModule.setRevShareForDerivatives()
            address[] memory parentIpIds = new address[](1);
            parentIpIds[0] = parentIpId;

            ROYALTY_MODULE.setRoyaltyPolicy(
                ipId,
                address(ROYALTY_POLICY_LS),
                parentIpIds,
                abi.encode(policy.derivativesRevShare) // uint32
            );
        }
        // If the policy defines the licensor must approve derivatives, check if the
        // derivative is approved by the licensor
        if (policy.derivativesApproval) {
            linkingOK = linkingOK && isDerivativeApproved(licenseId, ipId);
        }
        return linkingOK;
    }

    /// Called by licenseRegistry to verify policy parameters for minting a license
    /// @param policyWasInherited check if IP is subjected to it's parent's policy
    /// @param policyData the licensing policy to verify
    function verifyMint(
        address,
        bool policyWasInherited,
        address,
        address,
        uint256,
        bytes memory policyData
    ) external onlyLicenseRegistry returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        // If the policy defines no derivative is allowed, and policy was inherited,
        // we don't allow minting
        if (!policy.derivativesAllowed && policyWasInherited) {
            return false;
        }
        return true;
    }

    /// Called by licenseRegistry to verify policy parameters for transferring a license
    /// @param licenseId the ID of the license being transferred
    /// @param from address of the sender
    /// @param policyData the licensing policy to verify
    function verifyTransfer(
        uint256 licenseId,
        address from,
        address,
        uint256,
        bytes memory policyData
    ) external onlyLicenseRegistry returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        // If license is non-transferable, only the licensor can transfer out a license
        // (or be directly minted to someone else)
        if (!policy.transferable) {
            // True if from == licensor
            return from == LICENSE_REGISTRY.licensorIpId(licenseId);
        }
        return true;
    }

    /// @notice Fetchs a policy from the registry, decoding the raw bytes into a UMLPolicy struct
    /// @param policyId  The ID of the policy to fetch
    /// @return policy The UMLPolicy struct
    function getPolicy(uint256 policyId) public view returns (UMLPolicy memory policy) {
        Licensing.Policy memory protocolPolicy = LICENSE_REGISTRY.policy(policyId);
        if (protocolPolicy.policyFramework != address(this)) {
            // This should not happen.
            revert Errors.PolicyFrameworkManager__GettingPolicyWrongFramework();
        }
        policy = abi.decode(protocolPolicy.data, (UMLPolicy));
    }

    function policyToJson(bytes memory policyData) public view returns (string memory) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));

        /* solhint-disable */
        // Follows the OpenSea standard for JSON metadata

        // base json
        string memory json = string(
            '{"name": "Story Protocol License NFT", "description": "License agreement stating the terms of a Story Protocol IPAsset", "attributes": ['
        );

        // Attributions
        json = string(
            abi.encodePacked(
                json,
                '{"trait_type": "Attribution", "value": "',
                policy.attribution ? "true" : "false",
                '"},',
                '{"trait_type": "Transferable", "value": "',
                policy.transferable ? "true" : "false",
                '"},',
                '{"trait_type": "Commerical Use", "value": "',
                policy.commercialUse ? "true" : "false",
                '"},',
                '{"trait_type": "commercialAttribution", "value": "',
                policy.commercialAttribution ? "true" : "false",
                '"},',
                '{"trait_type": "commercialRevShare", "value": ',
                Strings.toString(policy.commercialRevShare),
                "},"
                '{"trait_type": "commercializers", "value": ['
            )
        );

        uint256 commercializerCount = policy.commercializers.length;
        for (uint256 i = 0; i < commercializerCount; ++i) {
            json = string(abi.encodePacked(json, '"', policy.commercializers[i], '"'));
            if (i != commercializerCount - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }

        json = string(
            abi.encodePacked(
                json,
                ']}, {"trait_type": "derivativesAllowed", "value": "',
                policy.derivativesAllowed ? "true" : "false",
                '"},',
                '{"trait_type": "derivativesAttribution", "value": "',
                policy.derivativesAttribution ? "true" : "false",
                '"},',
                '{"trait_type": "derivativesApproval", "value": "',
                policy.derivativesApproval ? "true" : "false",
                '"},',
                '{"trait_type": "derivativesReciprocal", "value": "',
                policy.derivativesReciprocal ? "true" : "false",
                '"},',
                '{"trait_type": "derivativesRevShare", "value": ',
                Strings.toString(policy.derivativesRevShare),
                "},"
                '{"trait_type": "territories", "value": ['
            )
        );

        uint256 territoryCount = policy.territories.length;
        for (uint256 i = 0; i < territoryCount; ++i) {
            json = string(abi.encodePacked(json, '"', policy.territories[i], '"'));
            if (i != territoryCount - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }

        json = string(abi.encodePacked(json, ']}, {"trait_type": "distributionChannels", "value": ['));

        uint256 distributionChannelCount = policy.distributionChannels.length;
        for (uint256 i = 0; i < distributionChannelCount; ++i) {
            json = string(abi.encodePacked(json, '"', policy.distributionChannels[i], '"'));
            if (i != distributionChannelCount - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }

        json = string(abi.encodePacked(json, "]}]}"));
        /* solhint-enable */

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(BasePolicyFrameworkManager, IERC165) returns (bool) {
        return
            super.supportsInterface(interfaceId) ||
            interfaceId == type(ILinkParamVerifier).interfaceId ||
            interfaceId == type(IMintParamVerifier).interfaceId ||
            interfaceId == type(ITransferParamVerifier).interfaceId;
    }

    /// Checks the configuration of commercial use and throws if the policy is not compliant
    /// @param policy The policy to verify
    function _verifyComercialUse(UMLPolicy calldata policy) internal view {
        if (!policy.commercialUse) {
            if (policy.commercialAttribution) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddAttribution();
            }
            if (policy.commercializers.length > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddCommercializers();
            }
            if (policy.commercialRevShare > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddRevShare();
            }
            if (policy.derivativesRevShare > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_CommecialDisabled_CantAddDerivRevShare();
            }
        }
    }

    /// Checks the configuration of derivative parameters and throws if the policy is not compliant
    /// @param policy The policy to verify
    function _verifyDerivatives(UMLPolicy calldata policy) internal pure {
        if (!policy.derivativesAllowed) {
            if (policy.derivativesAttribution) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddAttribution();
            }
            if (policy.derivativesApproval) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddApproval();
            }
            if (policy.derivativesReciprocal) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddReciprocal();
            }
            if (policy.derivativesRevShare > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager_DerivativesDisabled_CantAddRevShare();
            }
        }
    }
}
