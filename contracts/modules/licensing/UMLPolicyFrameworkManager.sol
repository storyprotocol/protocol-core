// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

// external
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
import { IUMLPolicyFrameworkManager, UMLPolicy, UMLAggregator, RegisterUMLPolicyParams } from "../../interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
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
    /// @dev Internally, this function must generate a Licensing.Policy struct and call registerPolicy.
    /// @param params parameters needed to register a UMLPolicy
    /// @return policyId The ID of the newly registered policy
    function registerPolicy(RegisterUMLPolicyParams calldata params) external nonReentrant returns (uint256 policyId) {
        _verifyComercialUse(params.policy, params.royaltyPolicy);
        _verifyDerivatives(params.policy);
        /// TODO: DO NOT deploy on production networks without hashing string[] values instead of storing them
        // No need to emit here, as the LicensingModule will emit the event
        return
            LICENSING_MODULE.registerPolicy(
                params.transferable,
                params.royaltyPolicy,
                abi.encode(params.policy.commercialRevShare), // TODO: this should be encoded by the royalty policy
                abi.encode(params.policy)
            );
    }

    /// @notice Verify policy parameters for linking a child IP to a parent IP (licensor) by burning a license NFT.
    /// @dev Enforced to be only callable by LicenseRegistry
    /// @param licenseId the license id to burn
    /// @param caller the address executing the link
    /// @param ipId the IP id of the IP being linked
    /// @param parentIpId the IP id of the parent IP
    /// @param policyData the encoded framework policy data to verify
    /// @return verified True if the link is verified
    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external override nonReentrant onlyLicensingModule returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));

        // Trying to burn a license to create a derivative, when the license doesn't allow derivatives.
        if (!policy.derivativesAllowed) {
            return false;
        }

        // If the policy defines the licensor must approve derivatives, check if the
        // derivative is approved by the licensor
        if (policy.derivativesApproval && !isDerivativeApproved(licenseId, ipId)) {
            return false;
        }
        // Check if the commercializerChecker allows the link
        if (policy.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(policy.commercializerChecker).verify(caller, policy.commercializerCheckerData)) {
                return false;
            }
        }
        return true;
    }

    /// @notice Verify policy parameters for minting a license.
    /// @dev Enforced to be only callable by LicenseRegistry
    /// @param caller the address executing the mint
    /// @param mintingFromADerivative true if the policy was inherited (licensorIpId is not original IP owner)
    /// @param licensorIpId the IP id of the licensor
    /// @param receiver the address receiving the license
    /// @param mintAmount the amount of licenses to mint
    /// @param policyData the encoded framework policy data to verify
    /// @return verified True if the link is verified
    function verifyMint(
        address caller,
        bool mintingFromADerivative,
        address licensorIpId,
        address receiver,
        uint256 mintAmount,
        bytes memory policyData
    ) external nonReentrant onlyLicensingModule returns (bool) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));
        // If the policy defines no reciprocal derivatives are allowed (no derivatives of derivatives),
        // and we are mintingFromADerivative we don't allow minting
        if (!policy.derivativesReciprocal && mintingFromADerivative) {
            return false;
        }

        if (policy.commercializerChecker != address(0)) {
            // No need to check if the commercializerChecker supports the IHookModule interface, as it was checked
            // when the policy was registered.
            if (!IHookModule(policy.commercializerChecker).verify(caller, policy.commercializerCheckerData)) {
                return false;
            }
        }

        return true;
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

    /// @notice gets the UMLPolicy for a given policy ID decoded from Licensing.Policy.frameworkData
    /// @dev Do not call this function from a smart contract, it is only for off-chain
    /// @param policyId The ID of the policy to get
    /// @return policy The UMLPolicy struct
    function getUMLPolicy(uint256 policyId) external view returns (UMLPolicy memory policy) {
        Licensing.Policy memory pol = LICENSING_MODULE.policy(policyId);
        return abi.decode(pol.frameworkData, (UMLPolicy));
    }

    /// @notice Verify compatibility of one or more policies when inheriting them from one or more parent IPs.
    /// @dev Enforced to be only callable by LicenseRegistry
    /// @dev The assumption in this method is that we can add parents later on, hence the need
    /// for an aggregator, if not we will do this when linking to parents directly with an
    /// array of policies.
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

    /// @notice Returns the stringified JSON policy data for the LicenseRegistry.uri(uint256) method.
    /// @dev Must return ERC1155 OpenSea standard compliant metadata.
    /// @param policyData The encoded licensing policy data to be decoded by the PFM
    /// @return jsonString The OpenSea-compliant metadata URI of the policy
    function policyToJson(bytes memory policyData) public pure returns (string memory) {
        UMLPolicy memory policy = abi.decode(policyData, (UMLPolicy));

        /* solhint-disable */
        // Follows the OpenSea standard for JSON metadata.
        // **Attributions**
        string memory json = string(
            abi.encodePacked(
                '{"trait_type": "Attribution", "value": "',
                policy.attribution ? "true" : "false",
                '"},',
                // Skip transferable, it's already added in the common attributes by the LicenseRegistry.
                // Should be managed by the LicenseRegistry, not the PFM.
                _policyCommercialTraitsToJson(policy),
                _policyDerivativeTraitsToJson(policy)
            )
        );

        json = string(abi.encodePacked(json, '{"trait_type": "Territories", "value": ['));
        uint256 count = policy.territories.length;
        for (uint256 i = 0; i < count; ++i) {
            json = string(abi.encodePacked(json, '"', policy.territories[i], '"'));
            if (i != count - 1) {
                // skip comma for last element in the array
                json = string(abi.encodePacked(json, ","));
            }
        }
        json = string(abi.encodePacked(json, "]},")); // close the trait_type: "Territories" array

        json = string(abi.encodePacked(json, '{"trait_type": "Distribution Channels", "value": ['));
        count = policy.distributionChannels.length;
        for (uint256 i = 0; i < count; ++i) {
            json = string(abi.encodePacked(json, '"', policy.distributionChannels[i], '"'));
            if (i != count - 1) {
                // skip comma for last element in the array
                json = string(abi.encodePacked(json, ","));
            }
        }
        json = string(abi.encodePacked(json, "]},")); // close the trait_type: "Distribution Channels" array

        // NOTE: (above) last trait added by PFM should have a comma at the end.

        /* solhint-enable */

        return json;
    }

    /// @dev Encodes the commercial traits of UML policy into a JSON string for OpenSea
    /// @param policy The policy to encode
    function _policyCommercialTraitsToJson(UMLPolicy memory policy) internal pure returns (string memory) {
        /* solhint-disable */
        // NOTE: TOTAL_RNFT_SUPPLY = 1000 in trait with max_value. For numbers, don't add any display_type, so that
        // they will show up in the "Ranking" section of the OpenSea UI.
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Commerical Use", "value": "',
                    policy.commercialUse ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Attribution", "value": "',
                    policy.commercialAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Commercial Revenue Share", "max_value": 1000, "value": ',
                    policy.commercialRevShare.toString(),
                    "},",
                    '{"trait_type": "Commercializer Check", "value": "',
                    policy.commercializerChecker.toHexString(),
                    // Skip on commercializerCheckerData as it's bytes as irrelevant for the user metadata
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Encodes the derivative traits of UML policy into a JSON string for OpenSea
    /// @param policy The policy to encode
    function _policyDerivativeTraitsToJson(UMLPolicy memory policy) internal pure returns (string memory) {
        /* solhint-disable */
        // NOTE: TOTAL_RNFT_SUPPLY = 1000 in trait with max_value. For numbers, don't add any display_type, so that
        // they will show up in the "Ranking" section of the OpenSea UI.
        return
            string(
                abi.encodePacked(
                    '{"trait_type": "Derivatives Allowed", "value": "',
                    policy.derivativesAllowed ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Attribution", "value": "',
                    policy.derivativesAttribution ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Approval", "value": "',
                    policy.derivativesApproval ? "true" : "false",
                    '"},',
                    '{"trait_type": "Derivatives Reciprocal", "value": "',
                    policy.derivativesReciprocal ? "true" : "false",
                    '"},'
                )
            );
        /* solhint-enable */
    }

    /// @dev Checks the configuration of commercial use and throws if the policy is not compliant
    /// @param policy The policy to verify
    /// @param royaltyPolicy The address of the royalty policy
    // solhint-disable-next-line code-complexity
    function _verifyComercialUse(UMLPolicy calldata policy, address royaltyPolicy) internal view {
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
            if (royaltyPolicy != address(0)) {
                revert UMLFrameworkErrors.UMLPolicyFrameworkManager__CommercialDisabled_CantAddRoyaltyPolicy();
            }
        } else {
            // TODO: check for supportInterface instead
            if (royaltyPolicy == address(0)) {
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
        }
    }

    /// @dev Verifies compatibility for params where the valid options are either permissive value, or equal params
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
