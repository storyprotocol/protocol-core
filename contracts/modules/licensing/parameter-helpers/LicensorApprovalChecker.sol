// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { AccessControlled } from "../../../access/AccessControlled.sol";
import { ILicenseRegistry } from "../../../interfaces/registries/ILicenseRegistry.sol";

/// @title LicensorApprovalChecker
/// @notice Manages the approval of derivative IP accounts by the licensor. Used to verify
/// licensing terms like "Derivatives With Approval" in PIL.
abstract contract LicensorApprovalChecker is AccessControlled {
    /// @notice Emits when a derivative IP account is approved by the licensor.
    /// @param licenseId The ID of the license waiting for approval
    /// @param ipId The ID of the derivative IP to be approved
    /// @param caller The executor of the approval
    /// @param approved Result of the approval
    event DerivativeApproved(uint256 indexed licenseId, address indexed ipId, address indexed caller, bool approved);

    /// @notice Returns the license registry address
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Approvals for derivative IP.
    /// @dev License Id => licensor => childIpId => approved
    mapping(uint256 => mapping(address => mapping(address => bool))) private _approvals;

    constructor(
        address accessController,
        address ipAccountRegistry,
        address licenseRegistry
    ) AccessControlled(accessController, ipAccountRegistry) {
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
    }

    /// @notice Approves or disapproves a derivative IP account.
    /// @param licenseId The ID of the license waiting for approval
    /// @param childIpId The ID of the derivative IP to be approved
    /// @param approved Result of the approval
    function setApproval(uint256 licenseId, address childIpId, bool approved) external {
        address licensorIpId = LICENSE_REGISTRY.licensorIpId(licenseId);
        _setApproval(licensorIpId, licenseId, childIpId, approved);
    }

    /// @notice Checks if a derivative IP account is approved by the licensor.
    /// @param licenseId The ID of the license NFT issued from a policy of the licensor
    /// @param childIpId The ID of the derivative IP to be approved
    /// @return approved True if the derivative IP account using the license is approved
    function isDerivativeApproved(uint256 licenseId, address childIpId) public view returns (bool) {
        address licensorIpId = LICENSE_REGISTRY.licensorIpId(licenseId);
        return _approvals[licenseId][licensorIpId][childIpId];
    }

    /// @notice Sets the approval for a derivative IP account.
    /// @dev This function is only callable by the licensor IP account.
    /// @param licensorIpId The ID of the licensor IP account
    /// @param licenseId The ID of the license waiting for approval
    /// @param childIpId The ID of the derivative IP to be approved
    /// @param approved Result of the approval
    function _setApproval(
        address licensorIpId,
        uint256 licenseId,
        address childIpId,
        bool approved
    ) internal verifyPermission(licensorIpId) {
        _approvals[licenseId][licensorIpId][childIpId] = approved;
        emit DerivativeApproved(licenseId, licensorIpId, msg.sender, approved);
    }
}
