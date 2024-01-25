// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IMintingParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ILinkParentParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { BaseParamVerifier } from "contracts/modules/licensing/parameters/BaseParamVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";

contract DerivativesParamVerifier is BaseParamVerifier, IMintingParamVerifier {
    string public constant override name = "Derivatives";

    event DerivativeApproved(address indexed licenseId, address indexed ipId, address indexed licensor, bool licensorApproval, bool approved);

    struct DerivativesConfig {
        // Derivatives
        bool derivativesAllowed;
        // Allowed-With-Attribution
        bool withAttribution;
        // Allowed-With-Approval -> cannot link to parent if ipId not approved by licensors
        bool withApproval; 
        bool withReciprocal; // Allowed-With-Reciprocal
        // Allowed-With-Revenue-Share
        // Can only be tagged if commercial use is allowed
        bool withRevenueShare;
        uint256 revenueSharePercentage;
        // TODO: Allowed-With-Revenue-Ceiling
    }

    // License Id => IP Id => licensor => approved
    mapping(licenseId => mapping(address => mapping(address => bool)) private _approvals;
    mapping(licenseId => mapping(address => uint256)) private _totalLicensorApprovals;

    constructor(address licenseRegistry) BaseParamVerifier(licenseRegistry) {

    }
    
    function encodeConfig(DerivativesConfig memory config) external pure returns (bytes memory) {
        if (!config.derivativesAllowed
            &&
            (config.withAttribution || config.withApproval || config.withReciprocal || config.withRevenueShare)
        ) {
            revert Errors.DerivativesParamVerifier__InvalidDerivativesConfig();
        }
        // TODO: check if commercial use is allowed? How do yo we enforce this on verification? we need structure
        if (config.withRevenueShare && config.revenueSharePercentage == 0) {
            revert Errors.DerivativesParamVerifier__ZeroShare();
        }
        return abi.encode(config);
    }

    function decodeConfig(bytes memory data) external pure returns (DerivativesConfig memory) {
        return abi.decode(data, (DerivativesConfig));
    }

    function setApproval(address licenseId, address ipId, bool approved) external {
        address[] memory licensors = LICENSE_REGISTRY.getLicensors(licenseId);
        uint256 totalLicensors = licensors.length;
        bool callerIsLicensor = false;
        for (uint256 i = 0; i < totalLicensors; i++) {
            if (caller == licensors[i]) {
                // TODO: check delegation too?
                callerIsLicensor = true;
                _approvals[licenseId][ipId][licensors[i]] = approved;
                uint256 totalApprovals = _totalLicensorApprovals[licenseId][ipId];
                if (approved) {
                    totalApprovals += 1;
                } else {
                    // If this reverts it's fine, revoking before any approval exists
                    // doesn't make sense
                    totalApprovals -= 1;
                }
                _totalLicensorApprovals[licenseId][ipId] = totalApprovals;
                emit DerivativeApproved(licenseId, ipId, licensors[i], approved, totalApprovals == totalLicensors);
            }
        }
        if (!callerIsLicensor) {
            revert Errors.DerivativesParamVerifier__Unauthorized();
        }
    }

    function isDerivativeApproved(address licenseId, address ipId) external view returns (bool) {
        return _totalLicensorApprovals[licenseId][ipId] == LICENSE_REGISTRY.getLicensors(licenseId).length;
    }

    function verifyMint(
        address licenseHolder,
        uint256 policyId,
        bool policyAddedByLinking,
        address[] memory licensors,
        uint256 amount,
        bytes memory data
    ) external view override returns (bool) {
        DerivativesConfig memory config = abi.decode(data, (DerivativesConfig));
        if (config.derivativesAllowed && config.withReciprocal) {
            // Permissionless
            return true;
        }
        if (policyAddedByLinking) {
            // Minting license for derivative ip
            if (!config.derivativesAllowed) {
                // If IP Licensor has not tagged “Derivatives”, then you are not allowed to create Derivative IP Assets.
                return false;
            }
        }
        // TODO: check delegation too
        uint256 totalLicensors = licensors.length;
        for (uint256 i = 0; i < totalLicensors; i++) {
            if (caller == licensors[i]) {
                // Caller is a licensor
                return true;
            }
        }
        // Caller is not a licensor
        return false;
    }

    function verifyLink(
        address licenseId,
        address licenseHolder,
        address ipId,
        address parentIpId,
        bytes calldata data
    ) external view override returns (bool) {
        DerivativesConfig memory config = abi.decode(data, (DerivativesConfig));
        if (config.withRevenueShare) {
            // TODO: setRoyaltyPolicy(ipId, parentIpId, config.revenueSharePercentage)
            // What happens if called twice?
        }
        if (config.withApproval) {

        } else {
            return true;
        }
    }

    function json() view returns (string memory) {
        return "";
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external pure override returns (bool) {
        DerivativesConfig memory config = abi.decode(data, (DerivativesConfig));
        return !config.withReciprocal;
    }
}



