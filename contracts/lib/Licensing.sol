// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;
import { IPolicyVerifier } from "../interfaces/licensing/IPolicyVerifier.sol";
import { Errors } from "./Errors.sol";

/// @title Licensing
/// @notice Types and constants used by the licensing related contracts
library Licensing {
    /// @notice Describes a license policy framework, which is a set of licensing terms (parameters)
    /// that come into effect in different moments of the licensing life cycle.
    /// Must correspond to human (or at least lawyer) readable text describing them in licenseUrl.
    /// To be valid in Story Protocol, the policy framework must be registered in the LicenseRegistry.
    /// @param policyFramework Address of the contract implementing the policy framework encoding and logic
    /// @param licenseUrl URL to the file containing the legal text for the license agreement
    struct PolicyFramework {
        address policyFramework;
        string licenseUrl;
    }

    /// @notice A particular configuration (flavor) of a Policy Framework, setting values for the licensing
    /// terms (parameters) of the framework.
    /// @param policyFrameworkId Id of the policy framework this policy is based on
    /// @param policyData Encoded data for the policy, specific to the policy framework
    struct Policy {
        uint256 policyFrameworkId;
        bytes data;
    }

    /// @notice Data that define a License Agreement NFT
    /// @param policyId Id of the policy this license is based on, which will be set in the derivative
    /// IP when the license is burnt
    /// @param licensorIpId Id of the IP this license is for
    struct License {
        uint256 policyId;
        address licensorIpId;
    }
}