// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Licensing } from "../lib/Licensing.sol";
import { IParamVerifier } from "../interfaces/licensing/IParamVerifier.sol";
import { Errors } from "../lib/Errors.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Burnable } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import "forge-std/console2.sol";

// TODO: consider disabling operators/approvals on creation
contract LicenseRegistry is ERC1155, ERC1155Burnable {

    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 => Licensing.Framework) private _frameworks;
    uint256 private _totalFrameworks;

    mapping(bytes32 => uint256) private _hashedPolicies;
    mapping(uint256 => Licensing.Policy) private _policies;
    uint256 private _totalPolicies;
    // DO NOT remove policies, that rugs derivatives and breaks ordering assumptions in set
    mapping(address => EnumerableSet.UintSet) private _policiesPerIpId;
    mapping(address => address[]) private _ipParents;

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

    // Protocol available terms
    function addLicenseFramework(Licensing.FrameworkCreationParams calldata fwCreation) external returns(uint256 frameworkId) {
        // check protocol auth
        if (bytes(fwCreation.licenseUrl).length == 0 || fwCreation.licenseUrl.equal("")) {
            revert Errors.LicenseRegistry__EmptyLicenseUrl(); 
        }
        // Todo: check duplications

        ++_totalFrameworks;
        console2.log("_totalFrameworks", _totalFrameworks);
        _frameworks[_totalFrameworks].licenseUrl = fwCreation.licenseUrl;
        _frameworks[_totalFrameworks].defaultNeedsActivation = fwCreation.defaultNeedsActivation;
        _setParamArray(_frameworks[_totalFrameworks], Licensing.ParamVerifierType.Minting, fwCreation.mintingParamVerifiers, fwCreation.mintingParamDefaultValues);
        _setParamArray(_frameworks[_totalFrameworks], Licensing.ParamVerifierType.Activate, fwCreation.activationParamVerifiers, fwCreation.activationParamDefaultValues);
        _setParamArray(_frameworks[_totalFrameworks], Licensing.ParamVerifierType.LinkParent, fwCreation.linkParentParamVerifiers, fwCreation.linkParentParamDefaultValues);
        // Should we add a label?
        // TODO: emit
        return _totalFrameworks;
    }

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

    function totalFrameworks() external view returns(uint256) {
        return _totalFrameworks;
    }

    function framework(uint256 frameworkId) external view returns(Licensing.Framework memory framework) {
        return _frameworks[frameworkId];
    }

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
 
    // Per IP ID
    // Sets available policies per IPID, returns policy Id. This is not a license.
    function addPolicy(address ipId, Licensing.Policy calldata pol) external returns(uint256 policyId, uint256 indexOnIpId) {
        // check protocol auth
        Licensing.Framework memory fw = _frameworks[pol.frameworkId];

        (uint256 polId, bool isNew) = _addIdOrGetExisting(abi.encode(pol), _hashedPolicies, _totalPolicies);
        policyId = polId;
        if (isNew) {
            _totalPolicies = polId;
            _policies[polId] = pol;
            // TODO: emit
        }
        return (policyId, _addPolictyId(ipId, policyId));
    }

    function _addPolictyId(address ipId, uint256 policyId) internal returns(uint256 index) {
        EnumerableSet.UintSet storage policySet = _policiesPerIpId[ipId];
        // TODO: check if policy is compatible with the others
        if (!policySet.add(policyId)) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        // TODO: emit
        return policySet.length() - 1;
    }


    function totalPolicies() external view returns(uint256) {
        return _totalPolicies;
    }

    function policy(uint256 policyId) external view returns(Licensing.Policy memory) {
        return _policies[policyId];
    }

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

    function mintLicense(Licensing.License calldata licenseData, uint256 amount, address receiver) external returns(uint256 licenseId) {
        for(uint256 i = 0; i < licenseData.licensorIpIds.length; i++) {
            // TODO: check if licensors are valid IP Ids and if they have been tagged bad
            // TODO: check if licensor allowed sender to mint in their behalf
        }
        
        uint256 polId = licenseData.policyId;
        Licensing.Policy memory pol = _policies[polId];
        if (pol.frameworkId == 0 || pol.frameworkId > _totalFrameworks) {
            revert Errors.LicenseRegistry__PolicyNotFound();
        }

        // TODO: execute minting params to check if they are valid

        (uint256 lId, bool isNew) = _addIdOrGetExisting(abi.encode(pol), _hashedLicenses, _totalLicenses);
        licenseId = lId;
        if (isNew) {
            _totalLicenses = licenseId;
            _licenses[licenseId] = licenseData;
            // TODO: emit
        }
        _mint(receiver, licenseId, amount, "");
        return licenseId;
    }

    function isLicensee(uint256 licenseId, address holder) external view returns(bool) {
        return balanceOf(holder, licenseId) > 0;
    }

    // TODO: activation method

}