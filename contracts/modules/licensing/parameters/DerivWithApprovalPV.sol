// // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { BaseParamVerifier } from "contracts/modules/licensing/parameters/BaseParamVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";

contract DerivWithApprovalPV is BaseParamVerifier, ILinkParamVerifier {

    event DerivativeApproved(uint256 indexed licenseId, address indexed ipId, address indexed caller, bool approved);

    // License Id => childIpId => approved
    mapping(uint256 => mapping(address => bool)) private _approvals;

    constructor(address licenseRegistry) BaseParamVerifier(licenseRegistry) {}

    // TODO: meta tx version
    function setApproval(uint256 licenseId, bool approved) external {
        address licensorIpId = LICENSE_REGISTRY.licensorIpId(licenseId);
        // TODO: ACL
        bool callerIsLicensor = true; // msg.sender is licensorIpId owner ;
        if (!callerIsLicensor) {
            revert Errors.DerivativesParamVerifier__Unauthorized();
        }
        _approvals[licenseId][licensorIpId] = approved;
        emit DerivativeApproved(licenseId, licensorIpId, msg.sender, approved);
    }

    function isDerivativeApproved(address licenseId, address licensorIpId) public view returns (bool) {
        return _approvals[licenseId][licensorIpId];
    }

    function verifyLink(
        address licenseId,
        address licenseHolder,
        address ipId,
        address parentIpId,
        bytes calldata data
    ) external view override returns (bool) {
        return isDerivativeApproved(licenseId, parentIpId);
    }

    function json() external pure override(IParamVerifier, BaseParamVerifier) returns (string memory) {
        return "";
    }

    function name() external pure override(IParamVerifier, BaseParamVerifier) returns (string memory) {
        return "Derivatives-With-Approval";
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external pure override(IParamVerifier, BaseParamVerifier) returns (bool) {
        return true;
    }
}



