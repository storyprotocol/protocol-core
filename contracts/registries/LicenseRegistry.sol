// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { Licensing } from "../lib/Licensing.sol";
import { IParamVerifier } from "../interfaces/licensing/IParamVerifier.sol";
import { Errors } from "../lib/Errors.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Burnable } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract LicenseRegistry is ERC1155, ERC1155Burnable {

    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 => Licensing.Framework) private _frameworks;
    uint256 private _totalFrameworks;

    mapping(bytes32 => uint256) private _hashedPolicies;
    mapping(uint256 => Licensing.Policy) private _policies;
    uint256 private _totalPolicies;

    mapping(address => EnumerableSet.UintSet) private _policiesPerIpId;
    mapping(address => address[]) private _ipParents;

    mapping(uint256 => Licensing.License) private _licenses;
    uint256 private _totalLicenses;

    constructor(string memory uri) ERC1155(uri) {}

    // Protocol available terms
    function addLicenseFramework(Licensing.FrameworkCreationParams calldata fwCreation) external returns(uint256 frameworkId) {
        if (bytes(fwCreation.licenseUrl).length == 0 || fwCreation.licenseUrl.equal("")) {
            revert Errors.LicenseRegistry__EmptyLicenseUrl(); 
        }
        // check protocol auth
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

    function framework(uint256 frameworkId) external view returns(Licensing.Framework memory) {
        return _frameworks[frameworkId];
    }

    function _addPolicyIdOrGetExisting(Licensing.Policy calldata pol) internal returns(uint256) {
        // We could just use the hash of the policy as id to save some gas, but the UX/DX of having huge random
        // numbers for ID is bad enough to justify the cost, plus we have accountability on current number of
        // policies.
        bytes32 policyHash = keccak256(abi.encode(pol));
        uint256 id = _hashedPolicies[policyHash];
        if (id != 0) {
            return id;
        }
        id = ++_totalPolicies;
        _hashedPolicies[policyHash] = id;
        _policies[id] = pol;
        // TODO: emit
        return id;
    }

 
    // Per IP ID
    // Sets available policies per IPID, returns policy Id. This is not a license.
    function addPolicy(address ipId, Licensing.Policy calldata pol) external returns(uint256 policyId, uint256 indexOnIpId) {
        // check protocol auth
        Licensing.Framework memory fw = _frameworks[pol.frameworkId];

        policyId = _addPolicyIdOrGetExisting(pol);
        return (policyId, _addPolictyId(ipId, policyId));
    }

    function _addPolictyId(address ipId, uint256 policyId) internal returns(uint256 index) {
        EnumerableSet.UintSet storage policySet = _policiesPerIpId[ipId];
        if (!policySet.add(policyId)) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        // TODO: emit
        return policySet.length() - 1;
    }

    // function _addPolictyId(address ipId, uint256 policyId) internal returns(uint256 index) {
    //     // TODO check for existance of ID before calling internal method
    // }

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

    // function linkIpaToParent(address ipId, address parentIpId, uint256 licenseId) external {
    //     // Check if parent is tagged
    //     if (_ownerOf(licenseId) != msg.sender) {
    //         revert "Not owner of license";
    //     }

    //     // if msg.sender == parent ipa or correct licensor
    //     for (uint i = 0; i < conditions.length; i++) {
    //         if (!conditions[i].isFulfilled(msg.sender, ) {
    //             revert PreConditionNotFulfilled();
    //         }
    //     }
    //     child.addParent(parent);
    //     _burn
    //     _mint
    // }
}