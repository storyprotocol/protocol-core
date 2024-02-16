// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

// external
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

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
/// @notice UML Policy Framework Manager implements the UML Policy Framework logic for encoding and decoding UML
/// policies into the LicenseRegistry and verifying the licensing parameters for linking, minting, and transferring.
contract UMLPolicyFrameworkManager is
    IUMLPolicyFrameworkManager,
    BasePolicyFrameworkManager,
    LicensorApprovalChecker,
    ReentrancyGuard
{
    using ERC165Checker for address;
    using Strings for *;

    /// @dev Hash of an empty string array
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
        LicensorApprovalChecker(
            accessController,
            ipAccountRegistry,
            address(ILicensingModule(licensing).LICENSE_REGISTRY())
        )
    {}

    /// @notice Registers a new policy to the registry
    /// @dev Must encode the policy into bytes to be stored in the LicenseRegistry
    /// @param umlPolicy UMLPolicy compliant licensing term values
    /// @return policyId The ID of the newly registered policy
    function registerPolicy(UMLPolicy calldata umlPolicy) external nonReentrant returns (uint256 policyId) {
        _verifyComercialUse(umlPolicy);
        _verifyDerivatives(umlPolicy);
        // No need to emit here, as the LicensingModule will emit the event

        return LICENSING_MODULE.registerPolicy(umlPolicy.transferable, abi.encode(umlPolicy));
    }

    /// @notice Verifies the given policy paramters when linking an IP asset with a parent IP asset.
    /// @dev Enforced to be only callable by the LicenseRegistry.
    /// @param licenseId The ID of the license NFT used for linking to parent IP
    /// @param caller The address of the caller
    /// @param ipId The ID of the child IP asset being linked to parent IP
    /// @param parentIpId The ID of the parent IP asset being linked to
    /// @param policyData The encoded licensing policy data to be decoded by the PFM for verification
    /// @return verifyLinkResponse The response of the linking verification
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external override nonReentrant onlyLicensingModule returns (IPolicyFrameworkManager.VerifyLinkResponse memory) {
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
        if (policy.commercializerChecker != address(0)) {
            if (!policy.commercializerChecker.supportsInterface(type(IHookModule).interfaceId)) {
                revert Errors.PolicyFrameworkManager__CommercializerCheckerDoesNotSupportHook(
                    policy.commercializerChecker
                );
            }

            if (!IHookModule(policy.commercializerChecker).verify(caller, policy.commercializerCheckerData)) {
                response.isLinkingAllowed = false;
            }
        }

        return response;
    }

    /// @notice Verifies the given policy paramters when minting a license NFT from an IP asset.
    /// @dev Enforced to be only callable by the LicenseRegistry.
    /// @param caller The address of the caller
    /// @param policyWasInherited Whether or not the policy was inherited from a parent IP asset
    /// @param licensor The address of the licensor (IP asset with the policy)
    /// @param receiver The address of the receiver to receive the minted license NFT
    /// @param mintAmount The amount of license NFTs to mint
    /// @param policyData The encoded licensing policy data to be decoded by the PFM for verification
    /// @return isMintAllowed True if the verification passed and minting is allowed
    function verifyMint(
        address caller,
        bool policyWasInherited,
        address licensor,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external nonReentrant onlyLicensingModule returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        // If the policy defines no derivative is allowed, and policy was inherited,
        // we don't allow minting
        if (!policy.derivativesAllowed && policyWasInherited) {
            return false;
        }

        if (policy.commercializerChecker != address(0)) {
            if (!policy.commercializerChecker.supportsInterface(type(IHookModule).interfaceId)) {
                revert Errors.PolicyFrameworkManager__CommercializerCheckerDoesNotSupportHook(
                    policy.commercializerChecker
                );
            }

            if (!IHookModule(policy.commercializerChecker).verify(caller, policy.commercializerCheckerData)) {
                return false;
            }
        }

        return true;
    }

    /// @notice Returns a policy from the registry, decoding the raw bytes into a UMLPolicy struct
    /// @param policyId The ID of the policy to fetch
    /// @return policy The UMLPolicy struct
    function getPolicy(uint256 policyId) public view returns (UMLPolicy memory policy) {
        Licensing.Policy memory protocolPolicy = LICENSING_MODULE.policy(policyId);
        if (protocolPolicy.policyFramework != address(this)) {
            // This should not happen.
            revert Errors.PolicyFrameworkManager__GettingPolicyWrongFramework();
        }
        policy = abi.decode(protocolPolicy.data, (UMLPolicy));
    }

    /// @notice Returns the policy ID for the given policy data, or 0 if not found
    /// @param umlPolicy The UMLPolicy struct to get the ID for
    /// @return policyId The ID of the policy
    function getPolicyId(UMLPolicy calldata umlPolicy) external view returns (uint256 policyId) {
        return LICENSING_MODULE.getPolicyId(address(this), umlPolicy.transferable, abi.encode(umlPolicy));
    }

    /// @notice Returns the aggregation data for inherited policies of an IP asset.
    /// @param ipId The ID of the IP asset to get the aggregator for
    /// @return rights The UMLAggregator struct
    function getAggregator(address ipId) external view returns (UMLAggregator memory rights) {
        bytes memory policyAggregatorData = LICENSING_MODULE.policyAggregatorData(address(this), ipId);
        if (policyAggregatorData.length == 0) {
            revert UMLFrameworkErrors.UMLPolicyFrameworkManager__RightsNotFound();
        }
        rights = abi.decode(policyAggregatorData, (UMLAggregator));
    }

    /// @notice Returns the royalty policy address of a policy ID belonging to the PFM
    /// @param policyId The policy ID to get
    /// @return royaltyPolicy The royalty policy address
    function getRoyaltyPolicy(uint256 policyId) external view returns (address) {
        return getPolicy(policyId).royaltyPolicy;
    }

    /// @notice Returns the commercial revenue share of a policy ID belonging to the PFM
    /// @param policyId The policy ID to get
    /// @return commercialRevenueShare The commercial revenue share of the policy
    function getCommercialRevenueShare(uint256 policyId) external view returns (uint32) {
        return getPolicy(policyId).commercialRevShare;
    }

    /// @notice Returns whether the policyId belonging to the PFM is commercial or non-commercial
    /// @param policyId The policy ID to check
    /// @return isCommercial True if the policy is commercial
    function isPolicyCommercial(uint256 policyId) external view returns (bool) {
        return getPolicy(policyId).commercialUse;
    }

    /// @notice Verify the compatibility of a policy with the current state of the IP asset, when inheriting from a
    /// parent IP. The current state of the IP asset, represented as the encoded aggregator bytes, is the combination
    /// of all policies previously attached to the IP asset.
    /// @dev Enforced to be only callable by the LicenseRegistry.
    /// @param aggregator The common state of the policies for the given IP asset
    /// @param policyId The ID of the new policy being inherited
    /// @param policy The encoded policy data of the policyId to inherit
    /// @return changedAgg True if the aggregator was changed
    /// @return newAggregator The new aggregator data, encoded
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

    /// @notice called by the LicenseRegistry uri(uint256) method.
    /// @dev Must return ERC1155 OpenSea standard compliant metadata.
    /// @param policyData The encoded licensing policy data to be decoded by the PFM
    /// @return string The OpenSea-compliant metadata URI of the policy
    function policyToJson(bytes memory policyData) public pure returns (string memory) {
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
            )
        );
        json = string(
            abi.encodePacked(
                json,
                '{"trait_type": "commercializerCheck", "value": "',
                policy.commercializerChecker.toHexString()
            )
        );
        // TODO: add commercializersData?
        json = string(
            abi.encodePacked(
                json,
                '"}, {"trait_type": "derivativesAllowed", "value": "',
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

    /// @notice Checks the configuration of commercial use and throws if the policy is not compliant
    /// @param policy The policy to verify
    // solhint-disable code-complexity
    function _verifyComercialUse(UMLPolicy calldata policy) internal view {
        if (!policy.commercialUse) {
            if (policy.commercialAttribution) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommecialDisabled_CantAddAttribution();
            }
            if (policy.commercializerChecker != address(0)) {
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
            if (policy.commercializerChecker != address(0)) {
                if (!policy.commercializerChecker.supportsInterface(type(IHookModule).interfaceId)) {
                    revert Errors.PolicyFrameworkManager__CommercializerCheckerDoesNotSupportHook(
                        policy.commercializerChecker
                    );
                }
                IHookModule(policy.commercializerChecker).validateConfig(policy.commercializerCheckerData);
            }
        }
    }

    /// @notice Checks the configuration of derivative parameters and throws if the policy is not compliant
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

    /// @notice Verifies compatibility for params where the valid options are either permissive value, or equal params
    /// @param oldHash hash of the old param
    /// @param newHash hash of the new param
    /// @param permissive hash of the most permissive param
    /// @return result the hash that's different from the permissive hash
    function _verifHashedParams(
        bytes32 oldHash,
        bytes32 newHash,
        bytes32 permissive
    ) internal pure returns (bytes32 result) {
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
