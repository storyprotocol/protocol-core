// // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { LicenseRegistryAware } from "contracts/modules/licensing/LicenseRegistryAware.sol";

// NOTE: this could be a standalone contract or part of a licensing module
abstract contract LicensorApprovalManager is LicenseRegistryAware {

    event DerivativeApproved(uint256 indexed licenseId, address indexed ipId, address indexed caller, bool approved);

    // License Id => childIpId => approved
    mapping(uint256 => mapping(address => bool)) private _approvals;

    // TODO: meta tx version?
    function setApproval(uint256 licenseId, bool approved) external {
        address licensorIpId = LICENSE_REGISTRY.licensorIpId(licenseId);
        // TODO: ACL
        bool callerIsLicensor = true; // msg.sender == IPAccountRegistry(licensorIpId).owner() or IP Account itself;
        if (!callerIsLicensor) {
            revert Errors.LicensorApprovalManager__Unauthorized();
        }
        _approvals[licenseId][licensorIpId] = approved;
        emit DerivativeApproved(licenseId, licensorIpId, msg.sender, approved);
    }

    function isDerivativeApproved(uint256 licenseId, address licensorIpId) public view returns (bool) {
        return _approvals[licenseId][licensorIpId];
    }

}



