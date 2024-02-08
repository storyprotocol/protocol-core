// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IIPAccount } from "../..//interfaces/IIPAccount.sol";
import { IPolicyFrameworkManager } from "../../interfaces/modules/licensing/IPolicyFrameworkManager.sol";
import { ILicenseRegistry } from "../../interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "../../interfaces/modules/licensing/ILicensingModule.sol";
import { IIPAccountRegistry } from "../../interfaces/registries/IIPAccountRegistry.sol";
import { Errors } from "../../lib/Errors.sol";
import { DataUniqueness } from "../../lib/DataUniqueness.sol";
import { Licensing } from "../../lib/Licensing.sol";
import { IPAccountChecker } from "../../lib/registries/IPAccountChecker.sol";
import { RoyaltyModule } from "../../modules/royalty-module/RoyaltyModule.sol";
import { IRoyaltyPolicy } from "../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { LICENSING_MODULE_KEY } from "../../lib/modules/Module.sol";

// TODO: consider disabling operators/approvals on creation
contract LicensingModule is AccessControlled, ILicensingModule {
    using IPAccountChecker for IIPAccountRegistry;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Licensing for *;
    using Strings for *;

    struct PolicySetup {
        uint256 index;
        bool isSet;
        bool active;
        bool isInherited;
    }

    RoyaltyModule public immutable ROYALTY_MODULE;
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    string public constant override name = LICENSING_MODULE_KEY;
    mapping(address framework => bool registered) private _registeredFrameworkManagers;
    mapping(bytes32 policyHash => uint256 policyId) private _hashedPolicies;
    mapping(uint256 policyId => Licensing.Policy policyData) private _policies;
    uint256 private _totalPolicies;
    /// @notice internal mapping to track if a policy was set by linking or minting, and the
    /// index of the policy in the ipId policy set
    /// Policies can't be removed, but they can be deactivated by setting active to false
    mapping(address ipId => mapping(uint256 policyId => PolicySetup setup)) private _policySetups;
    mapping(bytes32 hashIpIdAnInherited => EnumerableSet.UintSet policyIds) private _policiesPerIpId;
    mapping(address ipId => EnumerableSet.AddressSet parentIpIds) private _ipIdParents;
    mapping(address framework => mapping(address ipId => bytes policyAggregatorData)) private _ipRights;

    modifier onlyLicenseRegistry() {
        if (msg.sender == address(LICENSE_REGISTRY)) revert Errors.LicensingModule__CallerNotLicenseRegistry();
        _;
    }

    constructor(
        address accessController,
        address ipAccountRegistry,
        address royaltyModule,
        address registry
    ) AccessControlled(accessController, ipAccountRegistry) {
        ROYALTY_MODULE = RoyaltyModule(royaltyModule);
        LICENSE_REGISTRY = ILicenseRegistry(registry);
    }

    function licenseRegistry() external view returns (address) {
        return address(LICENSE_REGISTRY);
    }

    /// @notice registers a policy framework manager into the contract, so it can add policy data for
    /// licenses.
    /// @param manager the address of the manager. Will be ERC165 checked for IPolicyFrameworkManager
    function registerPolicyFrameworkManager(address manager) external {
        if (!ERC165Checker.supportsInterface(manager, type(IPolicyFrameworkManager).interfaceId)) {
            revert Errors.LicensingModule__InvalidPolicyFramework();
        }
        IPolicyFrameworkManager fwManager = IPolicyFrameworkManager(manager);
        string memory licenseUrl = fwManager.licenseTextUrl();
        if (bytes(licenseUrl).length == 0 || licenseUrl.equal("")) {
            revert Errors.LicensingModule__EmptyLicenseUrl();
        }
        _registeredFrameworkManagers[manager] = true;

        emit PolicyFrameworkRegistered(manager, fwManager.name(), licenseUrl);
    }

    /// Adds a policy to an ipId, which can be used to mint licenses.
    /// Licnses are permissions for ipIds to be derivatives (children).
    /// if policyId is not defined in LicenseRegistry, reverts.
    /// Will revert if ipId already has the same policy
    /// @param ipId to receive the policy
    /// @param polId id of the policy data
    /// @return indexOnIpId position of policy within the ipIds policy set
    function addPolicyToIp(address ipId, uint256 polId) external verifyPermission(ipId) returns (uint256 indexOnIpId) {
        if (!isPolicyDefined(polId)) {
            revert Errors.LicensingModule__PolicyNotFound();
        }

        indexOnIpId = _addPolicyIdToIp({ ipId: ipId, policyId: polId, isInherited: false, skipIfDuplicate: false });

        Licensing.Policy memory pol = policy(polId);

        // If the IPAccount has mutable royalty policy setting and the added policy is commercial, the IPAccount 
        // can change its royalty policy. This mutability will be set to false in two cases:
        // 1. `mintLicense`: when a child mints a license on a policy, it will lock in the value defined in that policy.
        // 2. `linkIpToParents`: when a child links to parents, it will lock in the value defined in the policies.
        //
        // Right now, we lock a global royalty address and min royalty value for the parent IPAccount. This limitation
        // is due to the Royalty Module's current design, which has a royalty tree that maps one royalty policy to one
        // IPAccount, not one policy attached to an IPAccount.
        if (pol.isCommercial) {
            if (!ROYALTY_MODULE.isRoyaltyPolicyImmutable(ipId)) {
                ROYALTY_MODULE.setRoyaltyPolicy(ipId, pol.royaltyConfig.rPolicy, new address[](0), pol.royaltyConfig.data);
            } else {
                ROYALTY_MODULE.verifyCanMintWihtImmutable(ipId, pol.royaltyConfig.rPolicy, pol.royaltyConfig.data);
            }
        }
    }

    /// @notice Registers a policy into the contract. MUST be called by a registered
    /// framework or it will revert. The policy data and its integrity must be
    /// verified by the policy framework manager.
    /// @param isLicenseTransferable True if the license is transferable
    /// @param data The policy data
    function registerPolicy(bool isLicenseTransferable, bool isCommercial, bytes memory data) external returns (uint256 policyId) {
        _verifyRegisteredFramework(address(msg.sender));
        Licensing.Policy memory pol = Licensing.Policy({
            isLicenseTransferable: isLicenseTransferable,
            isCommercial: isCommercial,
            policyFramework: msg.sender,
            data: data
        });
        (uint256 polId, bool newPol) = DataUniqueness.addIdOrGetExisting(
            abi.encode(pol),
            _hashedPolicies,
            _totalPolicies
        );

        if (!newPol) {
            revert Errors.LicensingModule__PolicyAlreadyAdded();
        } else {
            _totalPolicies = polId;
            _policies[polId] = pol;
            emit PolicyRegistered(msg.sender, polId, data);
        }

        return polId;
    }

    /// Mints license NFTs representing a policy granted by a set of ipIds (licensors). This NFT needs to be burned
    /// in order to link a derivative IP with its parents.
    /// If this is the first combination of policy and licensors, a new licenseId
    /// will be created (by incrementing prev totalLicenses).
    /// If not, the license is fungible and an id will be reused.
    /// The licensing terms that regulate creating new licenses will be verified to allow minting.
    /// Reverts if caller is not authorized by licensors.
    /// @param policyId id of the policy to be minted
    /// @param licensorIp IP Id granting the license
    /// @param amount of licenses to be minted. License NFT is fungible for same policy and same licensors
    /// @param receiver of the License NFT(s).
    /// @return licenseId of the NFT(s).
    function mintLicense(
        uint256 policyId,
        address licensorIp,
        uint256 amount, // mint amount
        address receiver
    ) external returns (uint256 licenseId) {
        // TODO: check if licensor has been tagged by disputer
        if (!IP_ACCOUNT_REGISTRY.isIpAccount(licensorIp)) {
            revert Errors.LicensingModule__LicensorNotRegistered();
        }

        bool isInherited = _policySetups[licensorIp][policyId].isInherited;
        Licensing.Policy memory pol = policy(policyId);

        // If the IP ID doesn't have a policy (meaning, no permissionless derivatives)
        if (!_policySetPerIpId(isInherited, licensorIp).contains(policyId)) {
            // We have to check if the caller is licensor or authorized to mint.
            if (!_hasPermission(licensorIp)) {
                revert Errors.LicensingModule__CallerNotLicensorAndPolicyNotSet();
            }

            // Ignore if the policy is non-commercial.
            if (pol.isCommercial) {

                // This if branch will get conditioned IF the caller is licensor and the policy is private, ie. not
                // attached to the IPAccount via `addPolicyToIp` (which makes it permissionless minting of licenses).
                // If the royalty policy of this IPAccount is not set in this case, then we set it. Addtionally, below
                // logics at the end of the function will set the Royalty module to be immutable, so we do not have to
                // set in this if branch directly.
                if (!ROYALTY_MODULE.isRoyaltyPolicyImmutable(licensorIp)) {
                    ROYALTY_MODULE.setRoyaltyPolicy(
                        licensorIp,
                        pol.royaltyConfig.rPolicy,
                        new address[](0),
                        pol.royaltyConfig.data
                    );
                } else {
                    ROYALTY_MODULE.verifyCanMintWihtImmutable(
                        licensorIp,
                        pol.royaltyConfig.rPolicy,
                        pol.royaltyConfig.data
                    );
                }
            }
        }
        // If a policy is set, then is only up to the policy params.
        // Verify minting param
        if (!IPolicyFrameworkManager(pol.policyFramework).verifyMint(msg.sender, isInherited, licensorIp, receiver, amount, pol.data)) {
            revert Errors.LicensingModule__MintLicenseParamFailed();
        }

        licenseId = LICENSE_REGISTRY.mintLicense(policyId, licensorIp, pol.isLicenseTransferable, amount, receiver);

        // If a policy is non-commercial, we do not need to check the royalty policy setting when minting a license.
        if (pol.isCommercial) {
            // When minting a license, if the commercial revenue share value defined in the policy is different
            // from the current min royalty of the parent IPAccount (that has the policy), then revert.
            // This is to prevent malicious users from front-running the license minting process, where the user
            // can mint a license with a higher/lower commercial revenue share value that LOCKS the parent IPAccount's
            // royalty policy setting (makes it IMMUTABLE).
            IRoyaltyPolicy(pol.royaltyConfig.rPolicy).verifyParamsMatch(pol.royaltyConfig.data);

            // If `commercialRevenueShare` = `minRoyalty` is true, this condition is checked.
            // If the parent of the to-be-minted license has a mutable royalty policy setting, then we set it as
            // IMMUTABLE. This locks the royalty policy address and min royalty for the parent to whatever value
            // it currently has set.
            if (!ROYALTY_MODULE.isRoyaltyPolicyImmutable(licensorIp)) {
                ROYALTY_MODULE.setRoyaltyPolicyImmutable(licensorIp);
            }
        }
    }

    /// @notice Links an IP to the licensors (parent IP IDs) listed in the License NFTs, if their policies allow it,
    /// burning the NFTs in the proccess. The caller must be the owner of the NFTs and the IP owner.
    /// @param licenseIds The id of the licenses to burn
    /// @param childIpId The id of the child IP to be linked
    /// @param royaltyInput input for the royalty policy
    function linkIpToParents(
        uint256[] calldata licenseIds,
        address childIpId,
        bytes calldata royaltyInput
    ) external verifyPermission(childIpId) {
        address holder = IIPAccount(payable(childIpId)).owner();
        address[] memory licensors = new address[](licenseIds.length);
        // If royalty policy address is address(0), this means no royalty policy to set.
        address royaltyPolicyAddress = address(0);

        bytes memory royaltyAccumulator;

        for (uint256 i = 0; i < licenseIds.length; i++) {
            uint256 licenseId = licenseIds[i];
            if (!LICENSE_REGISTRY.isLicensee(licenseId, holder)) {
                revert Errors.LicensingModule__NotLicensee();
            }
            Licensing.License memory licenseData = LICENSE_REGISTRY.license(licenseId);
            licensors[i] = licenseData.licensorIpId;

            Licensing.RoyaltyConfig memory rConfig = _linkIpToParent(
                i,
                licenseId,
                licenseData.policyId,
                licensors[i],
                childIpId
            );
            // If link says royalty is required for license (licenseIds[i]) and no royalty policy is set, set it.
            // But if the index is NOT 0, this is previous licenses didn't set the royalty policy because they don't
            // require royalty payment. So, revert in this case. Similarly, if the new royaltyPolicyAddress is different 
            // from the previous one (in iteration > 0), revert. We currently restrict all licenses (parents) to have 
            // the same royalty policy, so the child can inherit it.
            if (rConfig.rPolicy != address(0)) {
                if (i > 0 && royaltyPolicyAddress != rConfig.rPolicy) {
                    // If iteration > 0 and
                    // - royaltyPolicyAddress == address(0), revert. Previous licenses didn't set RP.
                    // - royaltyPolicyAddress != pol.royaltyConfig.rPolicy, revert. Previous licenses set different RP.
                    // ==> this can be considered as royaltyPolicyAddress != pol.royaltyConfig.rPolicy
                    revert Errors.LicensingModule__IncompatibleRoyaltyPolicyAddress();
                }
                royaltyAccumulator = IRoyaltyPolicy(rConfig.rPolicy).verifyMultiParentLinking(
                    royaltyAccumulator,
                    rConfig.data
                );
            }
            royaltyPolicyAddress = rConfig.rPolicy;
        }
        emit IpIdLinkedToParents(msg.sender, childIpId, licensors);

        // Licenses unanimously require royalty.
        if (royaltyPolicyAddress != address(0)) {
            bytes memory nextRPolicyData = IRoyaltyPolicy(royaltyPolicyAddress).childRoyaltyData(
                royaltyAccumulator,
                royaltyInput
            );
            ROYALTY_MODULE.setRoyaltyPolicy(
                childIpId,
                royaltyPolicyAddress,
                licensors,
                nextRPolicyData
            );
        }

        // Burn licenses
        LICENSE_REGISTRY.burnLicenses(holder, licenseIds);
    }

    function _linkIpToParent(
        uint256 iteration,
        uint256 licenseId,
        uint256 policyId,
        address licensor,
        address childIpId
    ) private returns (Licensing.RoyaltyConfig memory rConfig) {
        // TODO: check licensor not part of a branch tagged by disputer
        if (licensor == childIpId) {
            revert Errors.LicensingModule__ParentIdEqualThanChild();
        }
        // Verify linking params
        Licensing.Policy memory pol = policy(policyId);
        bool isLinkingAllowed = IPolicyFrameworkManager(pol.policyFramework)
            .verifyLink(licenseId, msg.sender, childIpId, licensor, pol.data);

        if (!isLinkingAllowed) {
            revert Errors.LicensingModule__LinkParentParamFailed();
        }

        // NOTE: response.isRoyaltyRequired is not policy.isCommercial, and the check for 
        // isCommercial true and royaltyPolicyAddress can't be 0 is done on policy registration.
        // OLD: Compatibility check: If link says no royalty is required for license (licenseIds[i]) but
        // another license requires royalty, revert.
        // if (!response.isRoyaltyRequired && royaltyPolicyAddress != address(0)) {
        //    revert Errors.LicensingModule__IncompatibleLicensorCommercialPolicy();
        // }

        // Add the policy of licenseIds[i] to the child. If the policy's already set from previous parents,
        // then the addition will be skipped.
        _addPolicyIdToIp({ ipId: childIpId, policyId: policyId, isInherited: true, skipIfDuplicate: true });
        // Set parent
        _ipIdParents[childIpId].add(licensor);
        return pol.royaltyConfig;
    }

    /// @notice True if the framework address is registered in LicenseRegistry
    function isFrameworkRegistered(address policyFramework) external view returns (bool) {
        return _registeredFrameworkManagers[policyFramework];
    }

    /// Returns amount of distinct licensing policies in LicenseRegistry
    function totalPolicies() external view returns (uint256) {
        return _totalPolicies;
    }

    /// Gets policy data for policyId, reverts if not found
    function policy(uint256 policyId) public view returns (Licensing.Policy memory pol) {
        pol = _policies[policyId];
        _verifyPolicy(pol);
        return pol;
    }

    function policyAggregatorData(address framework, address ipId) external view returns (bytes memory) {
        return _ipRights[framework][ipId];
    }

    /// Returns true if policyId is defined in LicenseRegistry, false otherwise.
    function isPolicyDefined(uint256 policyId) public view returns (bool) {
        return _policies[policyId].policyFramework != address(0);
    }

    /// Gets the policy set for an IpId
    /// @dev potentially expensive operation, use with care
    function policyIdsForIp(bool isInherited, address ipId) external view returns (uint256[] memory policyIds) {
        return _policySetPerIpId(isInherited, ipId).values();
    }

    function totalPoliciesForIp(bool isInherited, address ipId) public view returns (uint256) {
        return _policySetPerIpId(isInherited, ipId).length();
    }

    function isPolicyIdSetForIp(bool isInherited, address ipId, uint256 policyId) external view returns (bool) {
        return _policySetPerIpId(isInherited, ipId).contains(policyId);
    }

    function policyIdForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (uint256 policyId) {
        return _policySetPerIpId(isInherited, ipId).at(index);
    }

    function policyForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (Licensing.Policy memory) {
        return _policies[_policySetPerIpId(isInherited, ipId).at(index)];
    }

    function policyStatus(
        address ipId,
        uint256 policyId
    ) external view returns (uint256 index, bool isInherited, bool active) {
        PolicySetup storage setup = _policySetups[ipId][policyId];
        return (setup.index, setup.isInherited, setup.active);
    }

    function isPolicyInherited(address ipId, uint256 policyId) external view returns (bool) {
        return _policySetups[ipId][policyId].isInherited;
    }

    /// Returns true if the child is derivative from the parent, by at least 1 policy.
    function isParent(address parentIpId, address childIpId) external view returns (bool) {
        return _ipIdParents[childIpId].contains(parentIpId);
    }

    function parentIpIds(address ipId) external view returns (address[] memory) {
        return _ipIdParents[ipId].values();
    }

    function totalParentsForIpId(address ipId) external view returns (uint256) {
        return _ipIdParents[ipId].length();
    }

    function _verifyRegisteredFramework(address policyFramework) private view {
        if (!_registeredFrameworkManagers[policyFramework]) {
            revert Errors.LicensingModule__FrameworkNotFound();
        }
    }

    /// Adds a policy id to the ipId policy set
    /// Will revert if policy set already has policyId
    /// @param ipId the IP identifier
    /// @param policyId id of the policy data
    /// @param isInherited true if set in linkIpToParent, false otherwise
    /// @param skipIfDuplicate if true, will skip if policyId is already set
    /// @return index of the policy added to the set
    function _addPolicyIdToIp(
        address ipId,
        uint256 policyId,
        bool isInherited,
        bool skipIfDuplicate
    ) private returns (uint256 index) {
        _verifyCanAddPolicy(policyId, ipId, isInherited);
        // Try and add the policy into the set.
        EnumerableSet.UintSet storage _pols = _policySetPerIpId(isInherited, ipId);
        if (!_pols.add(policyId)) {
            if (skipIfDuplicate) {
                return _policySetups[ipId][policyId].index;
            }
            revert Errors.LicensingModule__PolicyAlreadySetForIpId();
        }
        index = _pols.length() - 1;
        PolicySetup storage setup = _policySetups[ipId][policyId];
        // This should not happen, but just in case
        if (setup.isSet) {
            revert Errors.LicensingModule__PolicyAlreadySetForIpId();
        }
        setup.index = index;
        setup.isSet = true;
        setup.active = true;
        setup.isInherited = isInherited;
        emit PolicyAddedToIpId(msg.sender, ipId, policyId, index, isInherited);
        return index;
    }

    function _verifyCanAddPolicy(uint256 policyId, address ipId, bool isInherited) private {
        bool ipIdIsDerivative = _policySetPerIpId(true, ipId).length() > 0;
        if (
            // Original work, owner is setting policies
            // (ipIdIsDerivative false, adding isInherited false)
            (!ipIdIsDerivative && !isInherited)
        ) {
            // Can add policy
            return;
        } else if (ipIdIsDerivative && !isInherited) {
            // Owner of derivative is trying to set policies
            revert Errors.LicensingModule__DerivativesCannotAddPolicy();
        }
        // If we are here, this is a multiparent derivative
        // Checking for policy compatibility
        IPolicyFrameworkManager polManager = IPolicyFrameworkManager(policy(policyId).policyFramework);
        Licensing.Policy memory pol = _policies[policyId];
        (bool aggregatorChanged, bytes memory newAggregator) = polManager.processInheritedPolicies(
            _ipRights[pol.policyFramework][ipId],
            policyId,
            pol.data
        );
        if (aggregatorChanged) {
            _ipRights[pol.policyFramework][ipId] = newAggregator;
        }
    }

    function _verifyPolicy(Licensing.Policy memory pol) private pure {
        if (pol.policyFramework == address(0)) {
            revert Errors.LicensingModule__PolicyNotFound();
        }
    }

    function _policySetPerIpId(bool isInherited, address ipId) private view returns (EnumerableSet.UintSet storage) {
        return _policiesPerIpId[keccak256(abi.encode(isInherited, ipId))];
    }
}
