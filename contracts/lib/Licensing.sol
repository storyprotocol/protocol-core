// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import { IParamVerifier } from "../interfaces/licensing/IParamVerifier.sol";

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
        Minting,
        Activate,
        LinkParent
    }

    /// Describes a licensing framework, which is a set of licensing terms (parameters)
    /// that come into effect in different moments of the licensing life cycle.
    /// Must correspond to human (or at least lawyer) readable text describing them in licenseUrl.
    /// To be valid in Story Protocol, the parameters described in the text must express default values
    /// corresponding to those of each Parameter struct
    struct Framework {
        /// These parameters need to be verified when minting a license
        Parameter[] mintingParams;
        /// License may need to be activated before linking, these parameters must be verified to activate.
        Parameter[] activationParams;
        /// The framework might have activation terms defined, but the default settings say they are disabled
        /// (so defaultNeedsActivation should be true). If the policy doesn't change this, it means licenses
        /// will be minted Active and can't be linked out of the box (if linkParentParams are true)
        bool defaultNeedsActivation;
        /// These parameters need to be verified so the owner of a license can link to a parent ipId/policy
        Parameter[] linkParentParams;
        /// URL to the file containing the legal text for the license agreement
        string licenseUrl;
    }

    // Needed because Solidity doesn't support passing nested struct arrays to storage
    struct FrameworkCreationParams {
        IParamVerifier[] mintingParamVerifiers;
        bytes[] mintingParamDefaultValues;
        IParamVerifier[] activationParamVerifiers;
        bytes[] activationParamDefaultValues;
        bool defaultNeedsActivation;
        IParamVerifier[] linkParentParamVerifiers;
        bytes[] linkParentParamDefaultValues;
        string licenseUrl;
    }

    /// A particular configuration of a Licensing Framework, setting (or not) values for the licensing
    /// terms (parameters) of the framework.
    /// The lengths of the param value arrays must correspond to the Parameter[] of the framework.
    struct Policy {
        /// Id of a Licensing Framework
        uint256 frameworkId;
        /// Array with values for parameters verifying conditions to mint a license. Empty bytes for index if
        /// this policy wants to use the default value for the paremeter.
        bytes[] mintingParamValues;
        /// Array with values for parameters verifying conditions to activate a license. Empty bytes for index if
        /// this policy wants to use the default value for the paremeter.
        bytes[] activationParamValues;
        /// If false, minted licenses will start activated and verification of activationParams will be skipped
        bool needsActivation;
        /// Array with values for params verifying conditions to link a license to a parent. Empty bytes for index if
        /// this policy wants to use the default value for the paremeter.
        bytes[] linkParentParamValues;
    }

    /// Data that define a License Agreement NFT
    struct License {
        /// the id for the Policy this License will set to the desired derivative IP after being burned.
        uint256 policyId;
        /// Ids for the licensors, meaning the Ip Ids of the parents of the derivative to be created
        address[] licensorIpIds;
    }
}
