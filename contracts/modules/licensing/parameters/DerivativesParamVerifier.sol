// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { BaseParamVerifier } from "contracts/modules/licensing/parameters/BaseParamVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// This corresponds with 1 term in UML text, but it's actually 5 interconnected parameters (hooks if you will)
/*
| Parameter                  | On chain              | Can be enabled if  | Can be enabled if | Incompatibility with other policy        | Side effect                          |   |
|----------------------------|-----------------------|--------------------|-------------------|------------------------------------------|--------------------------------------|---|
| Derivatives                | yes                   | -                  | -                 | -                                        | -                                    |   |
| Deriv With Attribution     | Yes (verify offchain) | Derivatives = true | -                 | -                                        | -                                    |   |
| Deriv With Approval        | yes                   | Derivatives = true | -                 | -                                        | –                                    |   |
| Deriv With Reciprocal      | yes                   | Derivatives = true | -                 | Disallow different policies on same IpId | Address other than licensor can mint |   |
| Deriv With Revenue Share   | yes                   | Derivatives = true | Commercial = true | -                                        | Royalties set on linking             |   |
| Deriv With Revenue Ceiling | no                    | Derivatives = true | Commercial = true | -                                        | -                                    |   |
*/
contract DerivativesParamVerifier is BaseParamVerifier, IMintParamVerifier, ILinkParamVerifier {

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
    mapping(uint256 => mapping(address => mapping(address => bool))) private _approvals;
    // License Id => IP Id => licensor => total approvals
    mapping(uint256 => mapping(address => uint256)) private _totalLicensorApprovals;

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
        address caller = msg.sender;
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

    function isDerivativeApproved(address licenseId, address ipId) public view returns (bool) {
        return _totalLicensorApprovals[licenseId][ipId] == LICENSE_REGISTRY.getLicensors(licenseId).length;
    }

    function verifyMint(
        address caller,
        uint256 policyId,
        bool policyAddedByLinking,
        address[] memory licensors,
        address receiver,
        uint256 amount,
        bytes memory data
    ) external view returns (bool) {
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
            return isDerivativeApproved(licenseId, ipId);
        }
        return true;
    }

    function json() external pure override(IParamVerifier, BaseParamVerifier) returns (string memory) {
        return "";
    }

    function name() external pure override(IParamVerifier, BaseParamVerifier) returns (string memory) {
        return "Derivatives";
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external pure override(IParamVerifier, BaseParamVerifier) returns (bool) {
        DerivativesConfig memory config = abi.decode(data, (DerivativesConfig));
        return !config.withReciprocal;
    }
}



