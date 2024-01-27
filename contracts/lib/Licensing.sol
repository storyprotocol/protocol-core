// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;
import { IParamVerifier } from "../interfaces/licensing/IParamVerifier.sol";
import { Errors } from "./Errors.sol";

library Licensing {
    /// Identifies a license parameter (term) from a license framework
    struct Parameter {
        /// Contract that must check if the condition of the paremeter is set
        IParamVerifier verifier;
        /// Default value for the parameter, as defined in the license framework text
        bytes defaultValue;
    }

    /// Moment of the license lifetime where a Parameter will be verified
    enum ParamVerifierType {
        Mint,
        LinkParent,
        Transfer
    }

    /// Describes a licensing framework, which is a set of licensing terms (parameters)
    /// that come into effect in different moments of the licensing life cycle.
    /// Must correspond to human (or at least lawyer) readable text describing them in licenseUrl.
    /// To be valid in Story Protocol, the parameters described in the text must express default values
    /// corresponding to those of each Parameter struct
    struct Framework {
        /// @notice Stores the parameters that need to be verified in each moment of the licensing lifetime
        mapping(bytes32 => Parameter) parameters;
        /// @notice URL to the file containing the legal text for the license agreement
        string licenseUrl;
    }

    // Needed because Solidity doesn't support passing nested struct arrays to storage
    struct FrameworkCreationParams {
        IParamVerifier[] parameters;
        bytes[] defaultValues;
        string licenseUrl;
    }

    /// A particular configuration of a Licensing Framework, setting (or not) values for the licensing
    /// terms (parameters) of the framework.
    struct Policy {
        /// True if the policy accepts commercial terms
        bool commercialUse;
        /// True if the policy accepts derivative-related terms
        bool derivatives;
        /// Id of a Licensing Framework
        uint256 frameworkId;
        /// Names of the parameters of the framework. Must be the same that IParamVerifier.name() returns
        bytes32[] paramNames;
        /// Values for the parameters of the framework. Index must correspond to paramNames[]
        bytes[] paramValues;
    }

    /// Data that define a License Agreement NFT
    struct License {
        /// the id for the Policy this License will set to the desired derivative IP after being burned.
        uint256 policyId;
        /// Id for the licensor of the Ip Id
        address licensorIpId;
    }
}
