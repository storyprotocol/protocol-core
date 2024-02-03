// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

// contracts
import { AccessControlled } from "contracts/access/AccessControlled.sol";
import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/licensing/IPolicyFrameworkManager.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";

// TODO: consider disabling operators/approvals on creation
contract LicenseRegistry is ERC1155, ILicenseRegistry, AccessControlled {
    using IPAccountChecker for IIPAccountRegistry;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for *;
    using ShortStrings for *;
    using Licensing for *;

    struct PolicySetup {
        uint256 index;
        bool isSet;
        bool active;
        bool isInherited;
    }

    RoyaltyModule public immutable ROYALTY_MODULE;

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
    mapping(address framework => mapping(address ipId => bytes rightsData)) private _ipRights;

    mapping(bytes32 licenseHash => uint256 ids) private _hashedLicenses;
    mapping(uint256 licenseIds => Licensing.License licenseData) private _licenses;
    /// This tracks the number of licenses registered in the protocol, it will not decrease when a license is burnt.
    uint256 private _totalLicenses;

    constructor(
        address accessController,
        address ipAccountRegistry,
        address royaltyModule
    ) ERC1155("") AccessControlled(accessController, ipAccountRegistry) {
        ROYALTY_MODULE = RoyaltyModule(royaltyModule);
    }

    /// @notice registers a policy framework manager into the contract, so it can add policy data for
    /// licenses.
    /// @param manager the address of the manager. Will be ERC165 checked for IPolicyFrameworkManager
    function registerPolicyFrameworkManager(address manager) external {
        if (!ERC165Checker.supportsInterface(manager, type(IPolicyFrameworkManager).interfaceId)) {
            revert Errors.LicenseRegistry__InvalidPolicyFramework();
        }
        IPolicyFrameworkManager fwManager = IPolicyFrameworkManager(manager);
        string memory licenseUrl = fwManager.licenseTextUrl();
        if (bytes(licenseUrl).length == 0 || licenseUrl.equal("")) {
            revert Errors.LicenseRegistry__EmptyLicenseUrl();
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
            revert Errors.LicenseRegistry__PolicyNotFound();
        }
        return _addPolicyIdToIp({ ipId: ipId, policyId: polId, isInherited: false, skipIfDuplicate: false });
    }

    /// @notice Registers a policy into the contract. MUST be called by a registered
    /// framework or it will revert. The policy data and its integrity must be
    /// verified by the policy framework manager.
    /// @param data The policy data
    function registerPolicy(bytes memory data) external returns (uint256 policyId) {
        _verifyRegisteredFramework(address(msg.sender));
        Licensing.Policy memory pol = Licensing.Policy({ policyFramework: msg.sender, data: data });
        (uint256 polId, bool newPol) = _addIdOrGetExisting(abi.encode(pol), _hashedPolicies, _totalPolicies);
        if (!newPol) {
            revert Errors.LicenseRegistry__PolicyAlreadyAdded();
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
            revert Errors.LicenseRegistry__LicensorNotRegistered();
        }
        bool isInherited = _policySetups[licensorIp][policyId].isInherited;
        // If the IP ID doesn't have a policy (meaning, no permissionless derivatives)
        if (!_policySetPerIpId(isInherited, licensorIp).contains(policyId)) {
            // We have to check if the caller is licensor or authorized to mint.
            if (!_hasPermission(licensorIp)) {
                revert Errors.LicenseRegistry__CallerNotLicensorAndPolicyNotSet();
            }
        }
        // If a policy is set, then is only up to the policy params.
        // Verify minting param
        Licensing.Policy memory pol = policy(policyId);
        if (ERC165Checker.supportsInterface(pol.policyFramework, type(IMintParamVerifier).interfaceId)) {
            if (
                !IMintParamVerifier(pol.policyFramework).verifyMint(
                    msg.sender,
                    isInherited,
                    licensorIp,
                    receiver,
                    amount,
                    pol.data
                )
            ) {
                revert Errors.LicenseRegistry__MintLicenseParamFailed();
            }
        }

        Licensing.License memory licenseData = Licensing.License({ policyId: policyId, licensorIpId: licensorIp });
        bool isNew;
        (licenseId, isNew) = _addIdOrGetExisting(abi.encode(licenseData), _hashedLicenses, _totalLicenses);
        if (isNew) {
            _totalLicenses = licenseId;
            _licenses[licenseId] = licenseData;
            emit LicenseMinted(msg.sender, receiver, licenseId, amount, licenseData);
        }
        _mint(receiver, licenseId, amount, "");
        return licenseId;
    }

    /// @notice Links an IP to the licensors (parent IP IDs) listed in the License NFTs, if their policies allow it,
    /// burning the NFTs in the proccess. The caller must be the owner of the NFTs and the IP owner.
    /// @param licenseIds The id of the licenses to burn
    /// @param childIpId The id of the child IP to be linked
    /// @param holder The address that holds the license
    function linkIpToParents(
        uint256[] calldata licenseIds,
        address childIpId,
        address holder
    ) external verifyPermission(childIpId) {
        address[] memory licensors = new address[](licenseIds.length);
        uint256[] memory values = new uint256[](licenseIds.length);
        // If royalty policy address is address(0), this means no royalty policy to set.
        // When a child passes in a royalty policy
        address royaltyPolicyAddress = address(0);
        uint32 royaltyDerivativeRevShare = 0;

        for (uint256 i = 0; i < licenseIds.length; i++) {
            if (balanceOf(holder, licenseIds[i]) == 0) {
                revert Errors.LicenseRegistry__NotLicensee();
            }
            Licensing.License memory licenseData = _licenses[licenseIds[i]];
            licensors[i] = licenseData.licensorIpId;
            // TODO: check licensor not part of a branch tagged by disputer
            if (licensors[i] == childIpId) {
                revert Errors.LicenseRegistry__ParentIdEqualThanChild();
            }
            // Verify linking params
            Licensing.Policy memory pol = policy(licenseData.policyId);
            if (ERC165Checker.supportsInterface(pol.policyFramework, type(ILinkParamVerifier).interfaceId)) {
                ILinkParamVerifier.VerifyLinkResponse memory response = ILinkParamVerifier(pol.policyFramework)
                    .verifyLink(licenseIds[i], msg.sender, childIpId, licensors[i], pol.data);

                if (!response.isLinkingAllowed) {
                    revert Errors.LicenseRegistry__LinkParentParamFailed();
                }

                // Compatibility check: If link says no royalty is required for license (licenseIds[i]) but
                // another license requires royalty, revert.
                if (!response.isRoyaltyRequired && royaltyPolicyAddress != address(0)) {
                    revert Errors.LicenseRegistry__IncompatibleLicensorRoyaltyPolicy();
                }

                // If link says royalty is required for license (licenseIds[i]) and no royalty policy is set, set it.
                // But if the index is NOT 0, this is previous licenses didn't set the royalty policy because they don't
                // require royalty payment. So, revert in this case.
                if (response.isRoyaltyRequired && royaltyPolicyAddress == address(0)) {
                    if (i != 0) {
                        revert Errors.LicenseRegistry__IncompatibleLicensorRoyaltyPolicy();
                    }
                    royaltyPolicyAddress = response.royaltyPolicy;
                    royaltyDerivativeRevShare = response.royaltyDerivativeRevShare;
                }
            }
            // Add the policy of licenseIds[i] to the child. If the policy's already set from previous parents,
            // then the addition will be skipped.
            _addPolicyIdToIp({
                ipId: childIpId,
                policyId: licenseData.policyId,
                isInherited: true,
                skipIfDuplicate: true
            });
            // Set parent
            _ipIdParents[childIpId].add(licensors[i]);
            values[i] = 1;
        }
        emit IpIdLinkedToParents(msg.sender, childIpId, licensors);

        // Licenses unanimously require royalty.
        if (royaltyPolicyAddress != address(0)) {
            ROYALTY_MODULE.setRoyaltyPolicy(
                childIpId,
                royaltyPolicyAddress,
                licensors,
                abi.encode(royaltyDerivativeRevShare)
            );
        }

        // Burn licenses
        _burnBatch(holder, licenseIds, values);
    }

    /// @notice True if the framework address is registered in LicenseRegistry
    function isFrameworkRegistered(address policyFramework) external view returns (bool) {
        return _registeredFrameworkManagers[policyFramework];
    }

    function name() external pure returns (string memory) {
        return "LICENSE_REGISTRY";
    }

    /// Returns true if holder has positive balance for licenseId
    function isLicensee(uint256 licenseId, address holder) external view returns (bool) {
        return balanceOf(holder, licenseId) > 0;
    }

    function policyIdForLicense(uint256 licenseId) external view returns (uint256) {
        return _licenses[licenseId].policyId;
    }

    function policyForLicense(uint256 licenseId) public view returns (Licensing.Policy memory) {
        return policy(_licenses[licenseId].policyId);
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

    function rightsData(address framework, address ipId) external view returns (bytes memory) {
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

    function license(uint256 licenseId) external view returns (Licensing.License memory) {
        return _licenses[licenseId];
    }

    function licensorIpId(uint256 licenseId) external view returns (address) {
        return _licenses[licenseId].licensorIpId;
    }

    /// @notice ERC1155 OpenSea metadata JSON representation of the LNFT parameters
    function uri(uint256 id) public view virtual override returns (string memory) {
        Licensing.License memory licenseData = _licenses[id];
        Licensing.Policy memory pol = policy(licenseData.policyId);
        return IPolicyFrameworkManager(pol.policyFramework).policyToJson(pol.data);
    }

    /// @dev Pre-hook for ERC1155's _update() called on transfers.
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // We are interested in transfers, minting and burning are checked in mintLicense and
        // linkIpToParent respectively.
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                // Verify transfer params
                Licensing.Policy memory pol = policy(_licenses[ids[i]].policyId);
                if (ERC165Checker.supportsInterface(pol.policyFramework, type(ITransferParamVerifier).interfaceId)) {
                    if (
                        !ITransferParamVerifier(pol.policyFramework).verifyTransfer(
                            ids[i],
                            from,
                            to,
                            values[i],
                            pol.data
                        )
                    ) {
                        revert Errors.LicenseRegistry__TransferParamFailed();
                    }
                }
            }
        }
        super._update(from, to, ids, values);
    }

    function _verifyRegisteredFramework(address policyFramework) private view {
        if (!_registeredFrameworkManagers[policyFramework]) {
            revert Errors.LicenseRegistry__FrameworkNotFound();
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
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        index = _pols.length() - 1;
        PolicySetup storage setup = _policySetups[ipId][policyId];
        // This should not happen, but just in case
        if (setup.isSet) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
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
            // or
            // IpId is becoming a derivative.
            // (ipIdIsDerivative false, adding isInherited true)
            // Next time, ipIdIsDerivative will be true
            (!ipIdIsDerivative)
        ) {
            // Can add policy
            return;
        } else if (ipIdIsDerivative && !isInherited) {
            // Owner of derivative is trying to set policies
            revert Errors.LicenseRegistry__DerivativesCannotAddPolicy();
        }
        // If we are here, this is a multiparent derivative
        // Checking for policy compatibility
        IPolicyFrameworkManager polManager = IPolicyFrameworkManager(policy(policyId).policyFramework);
        Licensing.Policy memory pol = _policies[policyId];
        (bool rightsChanged, bytes memory newRights) = polManager.processInheritedPolicies(
            _ipRights[pol.policyFramework][ipId],
            pol.data
        );
        if (rightsChanged) {
            _ipRights[pol.policyFramework][ipId] = newRights;
            emit IPRightsUpdated(ipId, newRights);
        }
    }

    /// Stores data without repetition, assigning an id to it if new or reusing existing one if already stored
    /// @param data raw bytes, abi.encode() a value to be hashed
    /// @param _hashToIds storage ref to the mapping of hash -> data id
    /// @param existingIds amount of distinct data stored.
    /// @return id new sequential id if new data, reused id if not new
    /// @return isNew True if a new id was generated, signaling the value was stored in _hashToIds.
    ///               False if id is reused and data was not stored
    function _addIdOrGetExisting(
        bytes memory data,
        mapping(bytes32 => uint256) storage _hashToIds,
        uint256 existingIds
    ) private returns (uint256 id, bool isNew) {
        // We could just use the hash of the policy as id to save some gas, but the UX/DX of having huge random
        // numbers for ID is bad enough to justify the cost, plus we have accountability on current number of
        // policies.
        bytes32 hash = keccak256(data);
        id = _hashToIds[hash];
        if (id != 0) {
            return (id, false);
        }
        id = existingIds + 1;
        _hashToIds[hash] = id;
        return (id, true);
    }

    function _verifyPolicy(Licensing.Policy memory pol) private pure {
        if (pol.policyFramework == address(0)) {
            revert Errors.LicenseRegistry__PolicyNotFound();
        }
    }

    function _policySetPerIpId(bool isInherited, address ipId) private view returns (EnumerableSet.UintSet storage) {
        return _policiesPerIpId[keccak256(abi.encode(isInherited, ipId))];
    }
}
