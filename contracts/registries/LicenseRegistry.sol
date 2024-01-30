// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

// contracts
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/licensing/IPolicyFrameworkManager.sol";

// TODO: consider disabling operators/approvals on creation
contract LicenseRegistry is ERC1155, ILicenseRegistry {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for *;
    using ShortStrings for *;
    using Licensing for *;

    struct PolicySetup {
        uint256 index;
        bool isSet;
        bool active;
        bool inheritedPolicy;
    }

    mapping(uint256 => Licensing.PolicyFramework) private _frameworks;
    uint256 private _totalFrameworks;

    mapping(bytes32 => uint256) private _hashedPolicies;
    mapping(uint256 => Licensing.Policy) private _policies;
    uint256 private _totalPolicies;
    /// @notice internal mapping to track if a policy was set by linking or minting, and the
    /// index of the policy in the ipId policy set
    /// Policies can't be removed, but they can be deactivated by setting active to false
    /// @dev ipId => policyId => PolicySetup
    mapping(address => mapping(uint256 => PolicySetup)) private _policySetups;
    mapping(address => EnumerableSet.UintSet) private _policiesPerIpId;

    mapping(address => EnumerableSet.AddressSet) private _ipIdParents;

    mapping(bytes32 => uint256) private _hashedLicenses;
    mapping(uint256 => Licensing.License) private _licenses;

    /// This tracks the number of licenses registered in the protocol, it will not decrease when a license is burnt.
    uint256 private _totalLicenses;

    modifier onlyLicensee(uint256 licenseId, address holder) {
        // Should ERC1155 operator count? IMO is a security risk. Better use ACL
        if (balanceOf(holder, licenseId) == 0) {
            revert Errors.LicenseRegistry__NotLicensee();
        }
        _;
    }

    constructor() ERC1155("") {}

    /// Adds a license framework to Story Protocol.
    /// Must be called by protocol admin
    /// @param fwCreation framework parameters
    /// @return policyFrameworkId identifier for framework, starting in 1
    function addPolicyFramework(
        Licensing.PolicyFramework calldata fwCreation
    ) external returns (uint256 policyFrameworkId) {
        // TODO: check protocol auth
        if (bytes(fwCreation.licenseUrl).length == 0 || fwCreation.licenseUrl.equal("")) {
            revert Errors.LicenseRegistry__EmptyLicenseUrl();
        }
        if (fwCreation.policyFramework == address(0)) {
            revert Errors.LicenseRegistry__ZeroPolicyFramework();
        }
        // Todo: check duplications

        ++_totalFrameworks;
        _frameworks[_totalFrameworks] = fwCreation;

        emit PolicyFrameworkCreated(msg.sender, _totalFrameworks, fwCreation);
        return _totalFrameworks;
    }

    /// Gets total frameworks supported by LicenseRegistry
    function totalFrameworks() external view returns (uint256) {
        return _totalFrameworks;
    }

    function _framework(uint256 policyFrameworkId) internal view returns (Licensing.PolicyFramework storage fw) {
        fw = _frameworks[policyFrameworkId];
        if (fw.policyFramework == address(0)) {
            revert Errors.LicenseRegistry__FrameworkNotFound();
        }
        return fw;
    }

    function framework(uint256 policyFrameworkId) external view returns (Licensing.PolicyFramework memory) {
        return _framework(policyFrameworkId);
    }

    function frameworkUrl(uint256 policyFrameworkId) external view returns (string memory) {
        return _framework(policyFrameworkId).licenseUrl;
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

    /// Adds a policy to an ipId, which can be used to mint licenses.
    /// Licnses are permissions for ipIds to be derivatives (children).
    /// if policyId is not defined in LicenseRegistry, reverts.
    /// Will revert if ipId already has the same policy
    /// @param ipId to receive the policy
    /// @param polId id of the policy data
    /// @return indexOnIpId position of policy within the ipIds policy set
    function addPolicyToIp(address ipId, uint256 polId) external returns (uint256 indexOnIpId) {
        if (!isPolicyDefined(polId)) {
            revert Errors.LicenseRegistry__PolicyNotFound();
        }
        return _addPolictyIdToIp(ipId, polId, false);
    }

    /// Adds a particular configuration of license terms to the protocol.
    /// Must be called by a PolicyFramework, which is responsible for verifying the parameters
    /// are valid and the configuration makes sense.
    /// @param pol policy data
    /// @return policyId if policy data was in the contract, policyId is reused, if it's new, id will be new.
    function addPolicy(Licensing.Policy memory pol) public returns (uint256 policyId) {
        address policyFramework = _framework(pol.policyFrameworkId).policyFramework;
        if (msg.sender != policyFramework) {
            revert Errors.LicenseRegistry__UnregisteredFrameworkAddingPolicy();
        }
        (uint256 polId, bool newPol) = _addIdOrGetExisting(abi.encode(pol), _hashedPolicies, _totalPolicies);
        if (!newPol) {
            revert Errors.LicenseRegistry__PolicyAlreadyAdded();
        } else {
            _totalPolicies = polId;
            _policies[polId] = pol;
            emit PolicyCreated(msg.sender, polId, pol);
        }
        return polId;
    }

    /// Adds a policy id to the ipId policy set
    /// Will revert if policy set already has policyId
    /// @param ipId the IP identifier
    /// @param policyId id of the policy data
    /// @param inheritedPolicy true if set in linkIpToParent, false otherwise
    /// @return index of the policy added to the set
    function _addPolictyIdToIp(address ipId, uint256 policyId, bool inheritedPolicy) internal returns (uint256 index) {
        EnumerableSet.UintSet storage _pols = _policiesPerIpId[ipId];
        if (!_pols.add(policyId)) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        // TODO: check for policy compatibility.
        // compatibilityManager.isPolicyCompatible(newPolicy, policiesInIpId);
        index = _pols.length() - 1;
        PolicySetup storage setup = _policySetups[ipId][policyId];
        // This should not happen, but just in case
        if (setup.isSet) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        setup.index = index;
        setup.isSet = true;
        setup.active = true;
        setup.inheritedPolicy = inheritedPolicy;
        emit PolicyAddedToIpId(msg.sender, ipId, policyId, index, inheritedPolicy);
        return index;
    }

    /// Returns amount of distinct licensing policies in LicenseRegistry
    function totalPolicies() external view returns (uint256) {
        return _totalPolicies;
    }

    /// Gets policy data for policyId, reverts if not found
    function policy(uint256 policyId) public view returns (Licensing.Policy memory pol) {
        pol = _policies[policyId];
        if (pol.policyFrameworkId == 0) {
            revert Errors.LicenseRegistry__PolicyNotFound();
        }
        return pol;
    }

    /// Returns true if policyId is defined in LicenseRegistry, false otherwise.
    function isPolicyDefined(uint256 policyId) public view returns (bool) {
        return _policies[policyId].policyFrameworkId != 0;
    }

    /// Gets the policy set for an IpId
    /// @dev potentially expensive operation, use with care
    function policyIdsForIp(address ipId) external view returns (uint256[] memory policyIds) {
        return _policiesPerIpId[ipId].values();
    }

    function totalPoliciesForIp(address ipId) external view returns (uint256) {
        return _policiesPerIpId[ipId].length();
    }

    function isPolicyIdSetForIp(address ipId, uint256 policyId) external view returns (bool) {
        return _policiesPerIpId[ipId].contains(policyId);
    }

    function policyIdForIpAtIndex(address ipId, uint256 index) external view returns (uint256 policyId) {
        return _policiesPerIpId[ipId].at(index);
    }

    function policyForIpAtIndex(address ipId, uint256 index) external view returns (Licensing.Policy memory) {
        return _policies[_policiesPerIpId[ipId].at(index)];
    }

    function indexOfPolicyForIp(address ipId, uint256 policyId) external view returns (uint256 index) {
        return _policySetups[ipId][policyId].index;
    }

    function isPolicyInherited(address ipId, uint256 policyId) external view returns (bool) {
        return _policySetups[ipId][policyId].inheritedPolicy;
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
        // TODO: check if licensor are valid IP Ids
        // TODO: check if licensor has been tagged by disputer
        // TODO: check if licensor allowed sender to mint in their behalf
        // TODO: licensor == msg.sender, expect if derivatives && withReciprocal
        if (licensorIp == address(0)) {
            revert Errors.LicenseRegistry__InvalidLicensor();
        }
        if (!_policiesPerIpId[licensorIp].contains(policyId)) {
            revert Errors.LicenseRegistry__LicensorDoesntHaveThisPolicy();
        }
        // Verify minting param
        Licensing.Policy memory pol = policy(policyId);
        Licensing.PolicyFramework storage fw = _framework(pol.policyFrameworkId);
        bool inheritedPolicy = _policySetups[licensorIp][policyId].inheritedPolicy;

        if (ERC165Checker.supportsInterface(fw.policyFramework, type(IMintParamVerifier).interfaceId)) {
            if (
                !IMintParamVerifier(fw.policyFramework).verifyMint(
                    msg.sender,
                    inheritedPolicy,
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

    /// Relates an IP ID with its parents (licensors), by burning the License NFT the holder owns
    /// Licensing parameters related to linking IPAs must be verified in order to succeed, reverts otherwise.
    /// The child IP ID will have the policy that the license represent added to it's own, if it's compatible with
    /// existing child policies.
    /// The child IP ID will be linked to the parent (if it wasn't before).
    /// @param licenseId license NFT to be burned
    /// @param childIpId that will receive the policy defined by licenseId
    /// @param holder of the license NFT
    function linkIpToParent(
        uint256 licenseId,
        address childIpId,
        address holder
    ) external onlyLicensee(licenseId, holder) {
        // TODO: check if childIpId exists and is owned by holder
        Licensing.License memory licenseData = _licenses[licenseId];
        address parentIpId = licenseData.licensorIpId;
        if (parentIpId == childIpId) {
            revert Errors.LicenseRegistry__ParentIdEqualThanChild();
        }
        // TODO: check licensor exist
        // TODO: check licensor not part of a branch tagged by disputer

        // Verify linking params
        Licensing.Policy memory pol = policy(licenseData.policyId);
        Licensing.PolicyFramework storage fw = _framework(pol.policyFrameworkId);

        if (ERC165Checker.supportsInterface(fw.policyFramework, type(ILinkParamVerifier).interfaceId)) {
            if (
                !ILinkParamVerifier(fw.policyFramework).verifyLink(
                    licenseId,
                    msg.sender,
                    childIpId,
                    parentIpId,
                    pol.data
                )
            ) {
                revert Errors.LicenseRegistry__LinkParentParamFailed();
            }
        }
        // Add policy to kid
        _addPolictyIdToIp(childIpId, licenseData.policyId, true);
        // Set parent
        _ipIdParents[childIpId].add(parentIpId);
        emit IpIdLinkedToParent(msg.sender, childIpId, parentIpId);

        // Burn license
        _burn(holder, licenseId, 1);
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
                Licensing.PolicyFramework storage fw = _framework(pol.policyFrameworkId);

                if (ERC165Checker.supportsInterface(fw.policyFramework, type(ITransferParamVerifier).interfaceId)) {
                    if (
                        !ITransferParamVerifier(fw.policyFramework).verifyTransfer(
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

    function uri(uint256 id) public view virtual override returns (string memory) {
        Licensing.License memory licenseData = _licenses[id];
        Licensing.Policy memory pol = policy(licenseData.policyId);
        Licensing.PolicyFramework storage fw = _framework(pol.policyFrameworkId);
        return IPolicyFrameworkManager(fw.policyFramework).policyToJson(pol.data);
    }
}
