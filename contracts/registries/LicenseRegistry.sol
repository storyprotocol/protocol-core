// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Licensing } from "../lib/Licensing.sol";
import { IParamVerifier } from "../interfaces/licensing/IParamVerifier.sol";
import { Errors } from "../lib/Errors.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Burnable } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";


// TODO: consider disabling operators/approvals on creation
contract LicenseRegistry is ERC1155, ERC1155Burnable {

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for *;

    mapping(uint256 => Licensing.Framework) private _frameworks;
    uint256 private _totalFrameworks;

    mapping(bytes32 => uint256) private _hashedPolicies;
    mapping(uint256 => Licensing.Policy) private _policies;
    uint256 private _totalPolicies;
    // DO NOT remove policies, that rugs derivatives and breaks ordering assumptions in set
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

    constructor(string memory uri) ERC1155(uri) {}

    /// Adds a license framework to Story Protocol.
    /// Must be called by protocol admin
    /// @param fwCreation parameters
    /// @return frameworkId identifier for framework, starting in 1
    function addLicenseFramework(Licensing.FrameworkCreationParams calldata fwCreation) external returns(uint256 frameworkId) {
        // check protocol auth
        if (bytes(fwCreation.licenseUrl).length == 0 || fwCreation.licenseUrl.equal("")) {
            revert Errors.LicenseRegistry__EmptyLicenseUrl(); 
        }
        // Todo: check duplications

        ++_totalFrameworks;
        _frameworks[_totalFrameworks].licenseUrl = fwCreation.licenseUrl;
        _frameworks[_totalFrameworks].defaultNeedsActivation = fwCreation.defaultNeedsActivation;
        _setParamArray(_frameworks[_totalFrameworks], Licensing.ParamVerifierType.Minting, fwCreation.mintingParamVerifiers, fwCreation.mintingParamDefaultValues);
        _setParamArray(_frameworks[_totalFrameworks], Licensing.ParamVerifierType.Activate, fwCreation.activationParamVerifiers, fwCreation.activationParamDefaultValues);
        _setParamArray(_frameworks[_totalFrameworks], Licensing.ParamVerifierType.LinkParent, fwCreation.linkParentParamVerifiers, fwCreation.linkParentParamDefaultValues);
        // Should we add a label?
        // TODO: emit
        return _totalFrameworks;
    }

    /// Convenience method to convert IParamVerifier[] + bytes[] into Parameter[], then stores it in a Framework storage ref
    /// (Parameter[] can be in storage but not in calldata)
    /// @param fw storage ref to framework
    /// @param pvType ParamVerifierType, to know which parameters the arrays correspond to
    /// @param paramVerifiers verifier array contracts
    /// @param paramDefaultValues default values for the verifiers. Must be equal in length with paramVerifiers
    function _setParamArray(
        Licensing.Framework storage fw,
        Licensing.ParamVerifierType pvType,
        IParamVerifier[] calldata paramVerifiers,
        bytes[] calldata paramDefaultValues
    ) private {
        if (paramVerifiers.length != paramDefaultValues.length) {
            revert Errors.LicenseRegistry__ParamVerifierLengthMismatch();
        }
        Licensing.Parameter[] storage params;
        if (pvType == Licensing.ParamVerifierType.Minting) {
            params = fw.mintingParams;
        } else if (pvType == Licensing.ParamVerifierType.Activate) {
            params = fw.activationParams;
        } else if (pvType == Licensing.ParamVerifierType.LinkParent) {
            params = fw.linkParentParams;
        } else {
            revert Errors.LicenseRegistry__InvalidParamVerifierType();
        }
        for (uint256 i = 0; i < paramVerifiers.length; i++) {
            params.push(Licensing.Parameter({
                verifier: paramVerifiers[i],
                defaultValue: paramDefaultValues[i]
            }));
        }
    }

    /// Gets total frameworks supported by LicenseRegistry
    function totalFrameworks() external view returns(uint256) {
        return _totalFrameworks;
    }

    /// Returns framework for id. Reverts if not found
    function framework(uint256 frameworkId) public view returns(Licensing.Framework memory fw) {
        fw = _frameworks[frameworkId];
        if (bytes(fw.licenseUrl).length == 0) {
            revert Errors.LicenseRegistry__FrameworkNotFound(); 
        }
        return fw;
    }

    /// Convenience method to store data without repetition, assigning an id to it if new or reusing the existing one if already stored
    /// @param data raw bytes, abi.encode() a value to be hashed
    /// @param _hashToIds storage ref to the mapping of hash -> data id
    /// @param existingIds amount of distinct data stored.
    /// @return id new sequential id if new data, reused id if not new
    /// @return isNew true if a new id was generated, signaling the value was stored in _hashToIds. False if id is reused and data was not stored
    function _addIdOrGetExisting(bytes memory data, mapping(bytes32 => uint256) storage _hashToIds, uint256 existingIds) private returns(uint256 id, bool isNew) {
        // We could just use the hash of the policy as id to save some gas, but the UX/DX of having huge random
        // numbers for ID is bad enough to justify the cost, plus we have accountability on current number of
        // policies.
        bytes32 hash = keccak256(data);
        uint256 id = _hashToIds[hash];
        if (id != 0) {
            return (id, false);
        }
        id = existingIds + 1;
        _hashToIds[hash] = id;
        return (id, true);
    }
 
    /// Adds a policy to an ipId, which can be used to mint licenses, which are permissions for ipIds to be derivatives (children).
    /// If an exact policy already existed, it will reuse the id.
    /// Will revert if ipId already has the same policy
    /// @param ipId to receive the policy
    /// @param pol policy data
    /// @return policyId if policy data was in the contract, policyId is reused, if it's new, id will be new.
    /// @return indexOnIpId position of policy within the ipIds policy set
    function addPolicy(address ipId, Licensing.Policy memory pol) public returns(uint256 policyId, uint256 indexOnIpId) {
        // check protocol auth
        Licensing.Framework memory fw = framework(pol.frameworkId);
        // TODO: check if policy is compatible with existing or is allowed to add more
        (uint256 polId, bool isNew) = _addIdOrGetExisting(abi.encode(pol), _hashedPolicies, _totalPolicies);
        policyId = polId;
        if (isNew) {
            _totalPolicies = polId;
            _policies[polId] = pol;
            // TODO: emit
        }
        return (policyId, _addPolictyId(ipId, policyId));
    }

    /// Adds a policy id to the ipId policy set
    /// Will revert if policy set already has policyId
    /// @param ipId the IP identifier
    /// @param policyId id of the policy data
    /// @return index of the policy added to the set
    function _addPolictyId(address ipId, uint256 policyId) internal returns(uint256 index) {
        EnumerableSet.UintSet storage policySet = _policiesPerIpId[ipId];
        // TODO: check if policy is compatible with the others
        if (!policySet.add(policyId)) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        // TODO: emit
        return policySet.length() - 1;
    }

    /// Returns amount of distinct licensing policies in LicenseRegistry
    function totalPolicies() external view returns(uint256) {
        return _totalPolicies;
    }

    /// Gets policy data for policyId, reverts if not found
    function policy(uint256 policyId) public view returns(Licensing.Policy memory pol) {
        pol = _policies[policyId];
        if (pol.frameworkId == 0) {
            revert Errors.LicenseRegistry__PolicyNotFound();
        }
        return pol;
    }

    /// Gets the policy set for an IpId
    /// @dev potentially expensive operation, use with care
    function policyIdsForIp(address ipId) external view returns(uint256[] memory policyIds) {
        return _policiesPerIpId[ipId].values();
    }

    function totalPoliciesForIp(address ipId) external view returns(uint256) {
        return _policiesPerIpId[ipId].length();
    }

    function isPolicyIdSetForIp(address ipId, uint256 policyId) external view returns(bool) {
        return _policiesPerIpId[ipId].contains(policyId);
    }

    function policyIdForIpAtIndex(address ipId, uint256 index) external view returns(uint256 policyId) {
        return _policiesPerIpId[ipId].at(index);
    }

    function policyForIpAtIndex(address ipId, uint256 index) external view returns(Licensing.Policy memory) {
        return _policies[_policiesPerIpId[ipId].at(index)];
    }

    /// Mints license NFTs representing a licensing policy granted by a set of ipIds (licensors). This NFT needs to be burned
    /// in order to link a derivative IP with its parents.
    /// If this is the first combination of policy and licensors, a new licenseId will be created (by incrementing prev totalLicenses).
    /// If not, the license is fungible and an id will be reused.
    /// The licensing terms that regulate creating new licenses will be verified to allow minting.
    /// Reverts if caller is not authorized by licensors.
    /// @param licenseData policy Id and licensors
    /// @param amount of licenses to be minted. License NFT is fungible for same policy and same licensors
    /// @param receiver of the License NFT(s).
    /// @return licenseId of the NFT(s).
    function mintLicense(Licensing.License calldata licenseData, uint256 amount, address receiver) external returns(uint256 licenseId) {
        uint256 policyId = licenseData.policyId;
        
        for(uint256 i = 0; i < licenseData.licensorIpIds.length; i++) {
            address licensor = licenseData.licensorIpIds[i];
            if(!_policiesPerIpId[licensor].contains(policyId)) {
                revert Errors.LicenseRegistry__LicensorDoesntHaveThisPolicy();
            }
            // TODO: check duplicates
            // TODO: check if licensors are valid IP Ids and if they have been tagged bad
            // TODO: check if licensor allowed sender to mint in their behalf
        }
        
        Licensing.Policy memory pol = policy(policyId);

        // TODO: execute minting params to check if they are valid

        (uint256 lId, bool isNew) = _addIdOrGetExisting(abi.encode(licenseData), _hashedLicenses, _totalLicenses);
        licenseId = lId;
        if (isNew) {
            _totalLicenses = licenseId;
            _licenses[licenseId] = licenseData;
            // TODO: emit
        }
        _mint(receiver, licenseId, amount, "");
        return licenseId;
    }

    /// Returns true if holder has positive balance for licenseId
    function isLicensee(uint256 licenseId, address holder) external view returns(bool) {
        return balanceOf(holder, licenseId) > 0;
    }

    /// Relates an IP ID with its parents (licensors), by burning the License NFT the holder owns
    /// License must be activated to succeed, reverts otherwise.
    /// Licensing parameters related to linking IPAs must be verified in order to succeed, reverts otherwise.
    /// The child IP ID will have the policy that the license represent added to it's own, if it's compatible with 
    /// existing child policies.
    /// The child IP ID will be linked to the parent (if it wasn't before).
    /// @param licenseId 
    /// @param childIpId 
    /// @param holder 
    function setParentPolicy(uint256 licenseId, address childIpId, address holder)
        external
        onlyLicensee(licenseId, holder) {
        // TODO: auth
        // TODO: check if license is activated
        // TODO: check if childIpId exists and is owned by holder
        Licensing.License memory licenseData = _licenses[licenseId];
        address[] memory parents = licenseData.licensorIpIds;
        for (uint256 i=0; i < parents.length; i++) {
            // TODO: check licensor exist
            // TODO: check licensor part of a bad tag branch
        }
        Licensing.Policy memory policy = policy(licenseData.policyId);
        // TODO: check linking conditions

        // Add policy to kid
        addPolicy(childIpId, policy);
        // Set parent
        for (uint256 i=0; i < parents.length; i++) {
            // We don't care if it was already a parent, because there might be a case such as:
            // 1. IP2 is created from IP1 with L1(non commercial)
            // 2. IP1 releases L2 with commercial terms, and IP2 wants permission to commercially exploit
            // 3. IP2 gets L2, burns it to set commercial policy
            address parent = parents[i];
            if (parent == childIpId) {
                revert Errors.LicenseRegistry__ParentIdEqualThanChild();
            }
            _ipIdParents[childIpId].add(parent);
            // TODO: emit
        }
        
        // Burn license
        _burn(holder, licenseId, 1);
    }

    /// Returns true if the child is derivative from the parent, by at least 1 policy.
    function isParent(address parentIpId, address childIpId) external view returns(bool) {
        return _ipIdParents[childIpId].contains(parentIpId);
    }

    function parentIpIds(address ipId) external view returns(address[] memory) {
        return _ipIdParents[ipId].values();
    }

    function totalParentsForIpId(address ipId) external view returns(uint256) {
        return _ipIdParents[ipId].length();
    }

    // TODO: activation method

    // TODO: tokenUri from parameters, from a metadata resolver contract

}