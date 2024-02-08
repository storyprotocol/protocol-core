// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

// external
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

// contracts
import { IHookModule } from "../../interfaces/modules/base/IHookModule.sol";
import { ILicensingModule } from "../../interfaces/modules/licensing/ILicensingModule.sol";
import { Licensing } from "../../lib/Licensing.sol";
import { Errors } from "../../lib/Errors.sol";
import { UMLFrameworkErrors } from "../../lib/UMLFrameworkErrors.sol";
// solhint-disable-next-line max-line-length
import { IUMLPolicyFrameworkManager, UMLPolicy, UMLAggregator } from "../../interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { IPolicyFrameworkManager } from "../../interfaces/modules/licensing/IPolicyFrameworkManager.sol";
import { BasePolicyFrameworkManager } from "../../modules/licensing/BasePolicyFrameworkManager.sol";
import { LicensorApprovalChecker } from "../../modules/licensing/parameter-helpers/LicensorApprovalChecker.sol";

/// @title UMLPolicyFrameworkManager
/// @notice This is the UML Policy Framework Manager, which implements the UML Policy Framework
/// logic for encoding and decoding UML policies into the LicenseRegistry and verifying
/// the licensing parameters for linking, minting, and transferring.
contract UMLPolicyFrameworkManager is IUMLPolicyFrameworkManager, BasePolicyFrameworkManager, LicensorApprovalChecker {
    using ERC165Checker for address;
    using Strings for *;

    bytes32 private constant _EMPTY_STRING_ARRAY_HASH =
        0x569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd;

    constructor(
        address accessController,
        address ipAccountRegistry,
        address licensing,
        string memory name_,
        string memory licenseUrl_
    )
        BasePolicyFrameworkManager(licensing, name_, licenseUrl_)
        LicensorApprovalChecker(accessController, ipAccountRegistry, ILicensingModule(licensing).licenseRegistry())
    {}

    /// @notice Re a new policy to the registry
    /// @dev Must encode the policy into bytes to be stored in the LicensingModule
    /// @param umlPolicy UMLPolicy compliant licensing term values
    function registerPolicy(UMLPolicy calldata umlPolicy) external returns (uint256 policyId) {
        _verifyComercialUse(umlPolicy);
        _verifyDerivatives(umlPolicy);
        // No need to emit here, as the LicensingModule will emit the event

        return LICENSING_MODULE.registerPolicy(umlPolicy.transferable, abi.encode(umlPolicy));
    }

    /// Called by licenseRegistry to verify policy parameters for linking an IP
    /// with the licensor's IP ID
    /// @param licenseId the ID of the license
    /// @param ipId the IP ID of the IP being linked
    /// @param policyData the licensing policy to verify
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address, // parentIpId
        bytes calldata policyData
    ) external override onlyLicensingModule returns (IPolicyFrameworkManager.VerifyLinkResponse memory) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        IPolicyFrameworkManager.VerifyLinkResponse memory response = IPolicyFrameworkManager.VerifyLinkResponse({
            isLinkingAllowed: true, // If you successfully mint and now hold a license, you have the right to link.
            isRoyaltyRequired: false,
            royaltyPolicy: address(0),
            royaltyDerivativeRevShare: 0
        });

        if (policy.commercialUse) {
            response.isRoyaltyRequired = true;
            response.royaltyPolicy = policy.royaltyPolicy;
            response.royaltyDerivativeRevShare = policy.derivativesRevShare;
        }

        // If the policy defines the licensor must approve derivatives, check if the
        // derivative is approved by the licensor
        if (policy.derivativesApproval) {
            response.isLinkingAllowed = response.isLinkingAllowed && isDerivativeApproved(licenseId, ipId);
        }

        for (uint256 i = 0; i < policy.commercializers.length; i++) {
            if (!policy.commercializers[i].supportsInterface(type(IHookModule).interfaceId)) {
                revert Errors.PolicyFrameworkManager__CommercializerDoesNotSupportHook(policy.commercializers[i]);
            }

            if (!IHookModule(policy.commercializers[i]).verify(caller, policy.commercializersData[i])) {
                response.isLinkingAllowed = false;
                break;
            }
        }

        return response;
    }

    /// Called by licenseRegistry to verify policy parameters for minting a license
    /// @param policyWasInherited check if IP is subjected to it's parent's policy
    /// @param policyData the licensing policy to verify
    function verifyMint(
        address caller,
        bool policyWasInherited,
        address,
        address,
        uint256,
        bytes memory policyData
    ) external onlyLicensingModule returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        // If the policy defines no derivative is allowed, and policy was inherited,
        // we don't allow minting
        if (!policy.derivativesAllowed && policyWasInherited) {
            return false;
        }

        for (uint256 i = 0; i < policy.commercializers.length; i++) {
            if (!policy.commercializers[i].supportsInterface(type(IHookModule).interfaceId)) {
                revert Errors.PolicyFrameworkManager__CommercializerDoesNotSupportHook(policy.commercializers[i]);
            }

            if (!IHookModule(policy.commercializers[i]).verify(caller, policy.commercializersData[i])) {
                return false;
            }
        }

        return true;
    }

    /// @notice Fetchs a policy from the registry, decoding the raw bytes into a UMLPolicy struct
    /// @param policyId  The ID of the policy to fetch
    /// @return policy The UMLPolicy struct
    function getPolicy(uint256 policyId) public view returns (UMLPolicy memory policy) {
        Licensing.Policy memory protocolPolicy = LICENSING_MODULE.policy(policyId);
        if (protocolPolicy.policyFramework != address(this)) {
            // This should not happen.
            revert Errors.PolicyFrameworkManager__GettingPolicyWrongFramework();
        }
        policy = abi.decode(protocolPolicy.data, (UMLPolicy));
    }

    /// @notice gets the aggregation data for inherited policies, decoded for the framework
    function getAggregator(address ipId) external view returns (UMLAggregator memory rights) {
        bytes memory policyAggregatorData = LICENSING_MODULE.policyAggregatorData(address(this), ipId);
        if (policyAggregatorData.length == 0) {
            revert UMLFrameworkErrors.UMLPolicyFrameworkManager__RightsNotFound();
        }
        rights = abi.decode(policyAggregatorData, (UMLAggregator));
    }

    function getPolicyId(UMLPolicy calldata umlPolicy) external view returns (uint256 policyId) {
        return LICENSING_MODULE.getPolicyId(address(this), umlPolicy.transferable, abi.encode(umlPolicy));
    }

    function getRoyaltyPolicy(uint256 policyId) external view returns (address) {
        return getPolicy(policyId).royaltyPolicy;
    }

    function getCommercialRevenueShare(uint256 policyId) external view returns (uint32) {
        return getPolicy(policyId).commercialRevShare;
    }

    function isPolicyCommercial(uint256 policyId) external view returns (bool) {
        return getPolicy(policyId).commercialUse;
    }

    /// Called by licenseRegistry to verify compatibility when inheriting from a parent IP
    /// The objective is to verify compatibility of multiple policies.
    /// @param aggregator common state of the policies for the IP
    /// @param policyId the ID of the policy being inherited
    /// @param policy the policy to inherit
    /// @return changedAgg  true if the aggregator was changed
    /// @return newAggregator the new aggregator
    // solhint-disable-next-line code-complexity
    function processInheritedPolicies(
        bytes memory aggregator,
        uint256 policyId,
        bytes memory policy
    ) external view onlyLicensingModule returns (bool changedAgg, bytes memory newAggregator) {
        UMLAggregator memory agg;
        UMLPolicy memory newPolicy = abi.decode(policy, (UMLPolicy));
        if (aggregator.length == 0) {
            // Initialize the aggregator
            agg = UMLAggregator({
                commercial: newPolicy.commercialUse,
                derivatives: newPolicy.derivativesAllowed,
                derivativesReciprocal: newPolicy.derivativesReciprocal,
                lastPolicyId: policyId,
                territoriesAcc: keccak256(abi.encode(newPolicy.territories)),
                distributionChannelsAcc: keccak256(abi.encode(newPolicy.distributionChannels)),
                contentRestrictionsAcc: keccak256(abi.encode(newPolicy.contentRestrictions))
            });
            return (true, abi.encode(agg));
        } else {
            agg = abi.decode(aggregator, (UMLAggregator));

            // Either all are reciprocal or none are
            if (agg.derivativesReciprocal != newPolicy.derivativesReciprocal) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__ReciprocalValueMismatch();
            } else if (agg.derivativesReciprocal && newPolicy.derivativesReciprocal) {
                // Ids are uniqued because we hash them to compare on creation in LicenseRegistry,
                // so we can compare the ids safely.
                if (agg.lastPolicyId != policyId) {
                    revert UMLFrameworkErrors.UMLPolicyFrameworkManager__ReciprocalButDifferentPolicyIds();
                }
            } else {
                // Both non reciprocal
                if (agg.commercial != newPolicy.commercialUse) {
                    revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialValueMismatch();
                }
                if (agg.derivatives != newPolicy.derivativesAllowed) {
                    revert UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesValueMismatch();
                }

                bytes32 newHash = _verifHashedParams(
                    agg.territoriesAcc,
                    keccak256(abi.encode(newPolicy.territories)),
                    _EMPTY_STRING_ARRAY_HASH
                );
                if (newHash != agg.territoriesAcc) {
                    agg.territoriesAcc = newHash;
                    changedAgg = true;
                }
                newHash = _verifHashedParams(
                    agg.distributionChannelsAcc,
                    keccak256(abi.encode(newPolicy.distributionChannels)),
                    _EMPTY_STRING_ARRAY_HASH
                );
                if (newHash != agg.distributionChannelsAcc) {
                    agg.distributionChannelsAcc = newHash;
                    changedAgg = true;
                }
                newHash = _verifHashedParams(
                    agg.contentRestrictionsAcc,
                    keccak256(abi.encode(newPolicy.contentRestrictions)),
                    _EMPTY_STRING_ARRAY_HASH
                );
                if (newHash != agg.contentRestrictionsAcc) {
                    agg.contentRestrictionsAcc = newHash;
                    changedAgg = true;
                }
            }
        }
        return (changedAgg, abi.encode(agg));
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
            json = string(abi.encodePacked(json, '"', policy.commercializers[i].toHexString(), '"'));
            if (i != commercializerCount - 1) {
                json = string(abi.encodePacked(json, ","));
            }
        }
        // TODO: add commercializersData?

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

    /// Checks the configuration of commercial use and throws if the policy is not compliant
    /// @param policy The policy to verify
    // solhint-disable code-complexity
    function _verifyComercialUse(UMLPolicy calldata policy) internal view {
        if (!policy.commercialUse) {
            if (policy.commercialAttribution) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddAttribution();
            }
            if (policy.commercializers.length > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialDisabled_CantAddCommercializers();
            }
            if (policy.commercialRevShare > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddRevShare();
            }
            if (policy.derivativesRevShare > 0) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddDerivRevShare();
            }
            if (policy.royaltyPolicy != address(0)) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialDisabled_CantAddRoyaltyPolicy();
            }
        } else {
            // TODO: check for supportInterface instead
            if (policy.royaltyPolicy == address(0)) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialEnabled_RoyaltyPolicyRequired();
            }
            if (policy.commercializers.length != policy.commercializersData.length) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercializersDataMismatch();
            }
        }
    }

    /// Checks the configuration of derivative parameters and throws if the policy is not compliant
    /// @param policy The policy to verify
    function _verifyDerivatives(UMLPolicy calldata policy) internal pure {
        if (!policy.derivativesAllowed) {
            if (policy.derivativesAttribution) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddAttribution();
            }
            if (policy.derivativesApproval) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddApproval();
            }
            if (policy.derivativesReciprocal) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddReciprocal();
            }
            if (policy.derivativesRevShare > 0) {
                // additional !policy.commecialUse is already checked in `_verifyComercialUse`
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__DerivativesDisabled_CantAddRevShare();
            }
        }
    }

    /// Verifies compatibility for params where the valid options are either permissive value, or equal params
    /// @param oldHash hash of the old param
    /// @param newHash hash of the new param
    /// @param permissive hash of the most permissive param
    /// @return result the hash that's different from the permissive hash
    function _verifHashedParams(
        bytes32 oldHash,
        bytes32 newHash,
        bytes32 permissive
    ) internal view returns (bytes32 result) {
        if (oldHash == newHash) {
            return newHash;
        }
        if (oldHash != permissive && newHash != permissive) {
            revert UMLFrameworkErrors.UMLPolicyFrameworkManager__StringArrayMismatch();
        }
        if (oldHash != permissive) {
            return oldHash;
        }
        if (newHash != permissive) {
            return newHash;
        }
    }
}
