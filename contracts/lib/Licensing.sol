// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import { IParamVerifier } from "../interfaces/licensing/IParamVerifier.sol";

library Licensing {

    struct Parameter {
        IParamVerifier verifier;
        bytes defaultValue;
    }

    enum ParamVerifierType {
        Minting,
        Activate,
        LinkParent
    }

    struct Framework {
        // These parameters need to be verified when minting a license
        Parameter[] mintingParams;
        // License may need to be activated before linking, these parameters must be verified to activate.
        Parameter[] activationParams;
        // If the framework defaults to not needing activation, this can be set to true to skip activateParams check.abi
        bool defaultNeedsActivation;
        // These parameters need to be verified so the owner of a license can link to a parent ipId/policy
        Parameter[] linkParentParams;
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
    
    struct Policy {
        uint256 frameworkId;
        bytes[] mintingParamValues;
        bytes[] activationParamValues;
        // must be set to true if policy will mint licenses without the need for activation
        bool needsActivation;
        bytes[] linkParentParamValues;
    }

    struct License {
        uint256 policyId;
        address[] licensorIpIds;
    }
}
