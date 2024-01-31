// // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { Errors } from "contracts/lib/Errors.sol";
import { LicenseRegistryAware } from "contracts/modules/licensing/LicenseRegistryAware.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";

/// @title LicensorApprovalManager
/// @notice Manages the approval of derivative IP accounts by the licensor. Used to verify
/// licensing terms like "Derivatives With Approval" in UML.
abstract contract LicensorApprovalManager is LicenseRegistryAware {
    /// Emits when a derivative IP account is approved by the licensor.
    /// @param licenseId id of the license waiting for approval
    /// @param ipId id of the derivative IP to be approved
    /// @param caller executor of the approval
    /// @param approved result of the approval
    event DerivativeApproved(uint256 indexed licenseId, address indexed ipId, address indexed caller, bool approved);

    IAccessController public immutable ACCESS_CONTROLLER;

    /// @notice Approvals for derivative IP.
    /// @dev License Id => licensor => childIpId => approved
    mapping(uint256 => mapping(address => mapping(address => bool))) private _approvals;

    constructor(address accessController) {
        ACCESS_CONTROLLER = IAccessController(accessController);
    }

    /// @notice Approves or disapproves a derivative IP account.
    /// @param licenseId id of the license waiting for approval
    /// @param childIpId id of the derivative IP to be approved
    /// @param approved result of the approval
    function setApproval(uint256 licenseId, address childIpId, bool approved) external {
        address licensorIpId = LICENSE_REGISTRY.licensorIpId(licenseId);
        if (!ACCESS_CONTROLLER.checkPermission(licensorIpId, msg.sender, address(this), msg.sig)) {
            revert Errors.LicensorApprovalManager__Unauthorized();
        }
        // TODO: meta tx version?
        bool callerIsLicensor = true; // msg.sender == IPAccountRegistry(licensorIpId).owner() or IP Account itself;
        if (!callerIsLicensor) {
            revert Errors.LicensorApprovalManager__Unauthorized();
        }
        _approvals[licenseId][licensorIpId][childIpId] = approved;
        emit DerivativeApproved(licenseId, licensorIpId, msg.sender, approved);
    }

    /// @notice Checks if a derivative IP account is approved by the licensor.
    function isDerivativeApproved(uint256 licenseId, address childIpId) public view returns (bool) {
        address licensorIpId = LICENSE_REGISTRY.licensorIpId(licenseId);
        return _approvals[licenseId][licensorIpId][childIpId];
    }
}
