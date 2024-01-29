// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// contract
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";

struct PolicyModifierParams {
    uint256 frameworkId;
    bytes32[] paramNames;
    bytes[] paramValues;
}

contract Integration_Shared_Policy {
    mapping(string policyName => uint256 globalPolicyId) internal policyIds;

    LicenseRegistry private licenseRegistry;

    function initPolicy(LicenseRegistry licenseRegistry_) public {
        licenseRegistry = licenseRegistry_;
    }

    modifier withPolicy_Commerical_Derivative(PolicyModifierParams memory params) {
        Licensing.Policy memory pol = _composePolicy(true, true, params);
        // pol.paramNames[0] = mockLicenseVerifier.name();
        // pol.paramValues[0] = abi.encode(true);
        string memory policyName = string(abi.encodePacked("com_deriv_", params.frameworkId));
        policyIds[policyName] = licenseRegistry.addPolicy(pol);
        _;
    }

    modifier withPolicy_Commerical_NonDerivative(PolicyModifierParams memory params) {
        Licensing.Policy memory pol = _composePolicy(true, false, params);
        string memory policyName = string(abi.encodePacked("com_nonderiv_", params.frameworkId));
        policyIds[policyName] = licenseRegistry.addPolicy(pol);
        _;
    }

    modifier withPolicy_NonCommerical_Derivative(PolicyModifierParams memory params) {
        Licensing.Policy memory pol = _composePolicy(false, true, params);
        string memory policyName = string(abi.encodePacked("noncom_deriv_", params.frameworkId));
        policyIds[policyName] = licenseRegistry.addPolicy(pol);
        _;
    }

    modifier withPolicy_NonCommerical_NonDerivative(PolicyModifierParams memory params) {
        Licensing.Policy memory pol = _composePolicy(false, false, params);
        string memory policyName = string(abi.encodePacked("noncom_nonderiv_", params.frameworkId));
        policyIds[policyName] = licenseRegistry.addPolicy(pol);
        _;
    }

    function _composePolicy(
        bool commercialUse,
        bool derivatives,
        PolicyModifierParams memory params
    ) private pure returns (Licensing.Policy memory) {
        return
            Licensing.Policy({
                frameworkId: params.frameworkId,
                commercialUse: commercialUse,
                derivatives: derivatives,
                paramNames: params.paramNames,
                paramValues: params.paramValues
            });
    }

    function _policyParams_AllTrue(
        uint256 frameworkId,
        address verifier
    ) internal view returns (PolicyModifierParams memory) {
        bytes32[] memory paramNames = new bytes32[](1);
        bytes[] memory paramValues = new bytes[](1);
        paramNames[0] = IParamVerifier(verifier).name();
        // MockVerifier: returns true
        // MintPaymentVerifier: value doesn't matter
        paramValues[0] = abi.encode(true);
        return PolicyModifierParams({ frameworkId: frameworkId, paramNames: paramNames, paramValues: paramValues });
    }
}
