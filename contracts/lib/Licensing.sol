// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title Licensing
/// @notice Types and constants used by the licensing related contracts
library Licensing {
    /// @notice A particular configuration (flavor) of a Policy Framework, setting values for the licensing
    /// terms (parameters) of the framework.
    /// @param policyFramework address of the IPolicyFrameworkManager this policy is based on
    /// @param isLicenseTransferable Whether or not the license is transferable
    /// @param data Encoded data for the policy, specific to the policy framework
    struct Policy {
        bool isLicenseTransferable;
        address policyFramework;
        bytes frameworkData;
        address royaltyPolicy;
        bytes royaltyData;
    }
    /// @notice Data that define a License Agreement NFT
    /// @param policyId Id of the policy this license is based on, which will be set in the derivative IP when the
    /// license is burnt for linking
    /// @param licensorIpId Id of the IP this license is for
    /// @param transferable Whether or not the license is transferable
    struct License {
        uint256 policyId;
        address licensorIpId;
        bool transferable;
        // TODO: support for transfer hooks
    }
}
