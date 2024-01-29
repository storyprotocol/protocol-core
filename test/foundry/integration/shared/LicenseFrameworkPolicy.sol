// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// contract
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";

struct PolicyModifierParams {
    string frameworkName;
    bytes32[] paramNames;
    bytes[] paramValues;
}

contract Integration_Shared_LicenseFramework_and_Policy {
    mapping(string frameworkName => uint256 frameworkId) internal frameworkIds;

    mapping(string policyName => uint256 globalPolicyId) internal policyIds;

    LicenseRegistry private licenseRegistry;

    function initLicenseFrameworkAndPolicy(LicenseRegistry licenseRegistry_) public {
        licenseRegistry = licenseRegistry_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                            MODIFIERS: LICENSE FRAMEWORK
    //////////////////////////////////////////////////////////////////////////*/

    modifier withLicenseFramework_Truthy(
        string memory name,
        address verifier
    ) {
        // All trues for MockVerifier means it will always return true on condition checks
        bytes[] memory byteValueTrue = new bytes[](1);
        byteValueTrue[0] = abi.encode(true);

        Licensing.FrameworkCreationParams memory fwAllTrue = Licensing.FrameworkCreationParams({
            parameters: new IParamVerifier[](1),
            defaultValues: byteValueTrue,
            licenseUrl: "https://very-nice-verifier-license.com"
        });

        fwAllTrue.parameters[0] = IParamVerifier(verifier);
        frameworkIds[name] = licenseRegistry.addLicenseFramework(fwAllTrue);
        _;
    }

    modifier withLicenseFramework_TruthyMany(
        string memory name,
        address[] memory verifiers,
        uint256 size
    ) {
        require(verifiers.length == size, "verifiers length != size");

        bytes[] memory byteValueTrue = new bytes[](size);
        for (uint256 i = 0; i < size; ++i) {
            byteValueTrue[i] = abi.encode(true);
        }

        Licensing.FrameworkCreationParams memory fwAllTrue = Licensing.FrameworkCreationParams({
            parameters: new IParamVerifier[](size),
            defaultValues: byteValueTrue,
            licenseUrl: "https://very-nice-verifier-license.com"
        });

        for (uint256 i = 0; i < size; ++i) {
            fwAllTrue.parameters[i] = IParamVerifier(verifiers[i]);
        }

        frameworkIds[name] = licenseRegistry.addLicenseFramework(fwAllTrue);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODIFIERS: POLICY
    //////////////////////////////////////////////////////////////////////////*/

    modifier withPolicy_Commerical_Derivative(PolicyModifierParams memory params) {
        Licensing.Policy memory pol = _composePolicy(true, true, params);
        // pol.paramNames[0] = mockLicenseVerifier.name();
        // pol.paramValues[0] = abi.encode(true);
        string memory policyName = string(abi.encodePacked("com_deriv_", params.frameworkName));
        policyIds[policyName] = licenseRegistry.addPolicy(pol);
        _;
    }

    modifier withPolicy_Commerical_NonDerivative(PolicyModifierParams memory params) {
        Licensing.Policy memory pol = _composePolicy(true, false, params);
        string memory policyName = string(abi.encodePacked("com_nonderiv_", params.frameworkName));
        policyIds[policyName] = licenseRegistry.addPolicy(pol);
        _;
    }

    modifier withPolicy_NonCommerical_Derivative(PolicyModifierParams memory params) {
        Licensing.Policy memory pol = _composePolicy(false, true, params);
        string memory policyName = string(abi.encodePacked("noncom_deriv_", params.frameworkName));
        policyIds[policyName] = licenseRegistry.addPolicy(pol);
        _;
    }

    modifier withPolicy_NonCommerical_NonDerivative(PolicyModifierParams memory params) {
        Licensing.Policy memory pol = _composePolicy(false, false, params);
        string memory policyName = string(abi.encodePacked("noncom_nonderiv_", params.frameworkName));
        policyIds[policyName] = licenseRegistry.addPolicy(pol);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _composePolicy(
        bool commercialUse,
        bool derivatives,
        PolicyModifierParams memory params
    ) private view returns (Licensing.Policy memory) {
        return
            Licensing.Policy({
                frameworkId: frameworkIds[params.frameworkName],
                commercialUse: commercialUse,
                derivatives: derivatives,
                paramNames: params.paramNames,
                paramValues: params.paramValues
            });
    }

    function _policyParams_Truthy(
        string memory frameworkName,
        address verifier
    ) internal view returns (PolicyModifierParams memory) {
        bytes32[] memory paramNames = new bytes32[](1);
        bytes[] memory paramValues = new bytes[](1);
        paramNames[0] = IParamVerifier(verifier).name();
        paramValues[0] = abi.encode(true);
        return
            PolicyModifierParams({
                frameworkName: frameworkName,
                paramNames: paramNames,
                paramValues: paramValues
            });
    }

    function _policyParams_TruthyMany(
        string memory frameworkName,
        address[] memory verifiers,
        uint256 size
    ) internal view returns (PolicyModifierParams memory) {
        require(verifiers.length == size, "verifiers length != size");
        bytes32[] memory paramNames = new bytes32[](size);
        bytes[] memory paramValues = new bytes[](size);
        for (uint256 i = 0; i < size; ++i) {
            paramNames[i] = IParamVerifier(verifiers[i]).name();
            paramValues[i] = abi.encode(true);
        }
        return
            PolicyModifierParams({
                frameworkName: frameworkName,
                paramNames: paramNames,
                paramValues: paramValues
            });
    }
}
