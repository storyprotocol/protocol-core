// SPDX-License-Identifier: MIT

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
        /// @notice Stores the parameters that need to be verified in each moment of the license lifetime
        /// ParamVerifierType.Mint --> These parameters need to be verified when minting a license
        /// ParamVerifierType.LinkParent --> Verified before the owner of a license links to a parent ipId/policy,
        /// burning the license and setting the policy for the ipId.
        /// ParamVerifierType.Transfer -> verified when transfering NFT
        mapping(ParamVerifierType => Parameter[]) parameters;
        /// @notice URL to the file containing the legal text for the license agreement
        string licenseUrl;
    }

    // Needed because Solidity doesn't support passing nested struct arrays to storage
    struct FrameworkCreationParams {
        IParamVerifier[] mintingVerifiers;
        bytes[] mintingDefaultValues;
        IParamVerifier[] linkParentVerifiers;
        bytes[] linkParentDefaultValues;
        IParamVerifier[] transferVerifiers;
        bytes[] transferDefaultValues;
        string licenseUrl;
    }
    
    /// A particular configuration of a Licensing Framework, setting (or not) values fo the licensing
    /// terms (parameters) of the framework.
    /// The lengths of the param value arrays must correspond to the Parameter[] of the framework.
    struct Policy {
        /// Id of a Licensing Framework
        uint256 frameworkId;
        /// Array with values for parameters verifying conditions to mint a license. Empty bytes for index if
        /// this policy wants to use the default value for the paremeter.
        bytes[] mintingParamValues;
        /// Array with values for parameters verifying conditions to link a license to a parent. Empty bytes for index if
        /// this policy wants to use the default value for the paremeter.
        bytes[] linkParentParamValues;
        /// Array with values for parameters verifying conditions to transfer a license. Empty bytes for index if
        /// this policy wants to use the default value for the paremeter.
        bytes[] transferParamValues;
    }

    function getValues(Policy memory policy, ParamVerifierType pvt) internal returns(bytes[] memory) {
        if (pvt == ParamVerifierType.Mint) {
            return policy.mintingParamValues;
        } else if (pvt == ParamVerifierType.LinkParent) {
            return policy.linkParentParamValues;
        } else if (pvt == ParamVerifierType.Transfer) {
            return policy.transferParamValues;
        } else {
            revert Errors.LicenseRegistry__InvalidParamVerifierType();
        }
    }

    /// Data that define a License Agreement NFT
    struct License {
        /// the id for the Policy this License will set to the desired derivative IP after being burned.
        uint256 policyId;
        /// Ids for the licensors, meaning the Ip Ids of the parents of the derivative to be created
        address[] licensorIpIds;
    }
}
