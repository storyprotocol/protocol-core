// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;
import { IParamVerifier } from "../interfaces/licensing/IParamVerifier.sol";
import { Errors } from "./Errors.sol";

library Licensing {

    /// Describes a licensing framework, which is a set of licensing terms (parameters)
    /// that come into effect in different moments of the licensing life cycle.
    /// Must correspond to human (or at least lawyer) readable text describing them in licenseUrl.
    /// To be valid in Story Protocol, the parameters described in the text must express default values
    /// corresponding to those of each Parameter struct
    struct PolicyFramework {
        address policyFramework;
        /// @notice URL to the file containing the legal text for the license agreement
        string licenseUrl;
    }

    /// A particular configuration of a Licensing PolicyFramework, setting (or not) values for the licensing
    /// terms (parameters) of the framework.
    struct Policy {
        /// Id of a Licensing PolicyFramework
        uint256 frameworkId;
        bytes data;
    }

    /// Data that define a License Agreement NFT
    struct License {
        /// the id for the Policy this License will set to the desired derivative IP after being burned.
        uint256 policyId;
        /// Id for the licensor of the Ip Id
        address licensorIpId;
    }
}