// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// contract
import { IAccessController } from "../../../contracts/interfaces/IAccessController.sol";
import { IIPAccountRegistry } from "../../../contracts/interfaces/registries/IIPAccountRegistry.sol";
import { ILicensingModule } from "../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicyLAP } from "../../../contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { BasePolicyFrameworkManager } from "../../../contracts/modules/licensing/BasePolicyFrameworkManager.sol";
// solhint-disable-next-line max-line-length
import { UMLPolicyFrameworkManager, UMLPolicy, RegisterUMLPolicyParams } from "../../../contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// test
// solhint-disable-next-line max-line-length
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";

contract LicensingHelper {
    IAccessController private ACCESS_CONTROLLER; // keep private to avoid collision with `BaseIntegration`

    IIPAccountRegistry private IP_ACCOUNT_REGISTRY; // keep private to avoid collision with `BaseIntegration`

    ILicensingModule private LICENSING_MODULE; // keep private to avoid collision with `BaseIntegration`

    IRoyaltyModule private ROYALTY_MODULE; // keep private to avoid collision with `BaseIntegration`

    IRoyaltyPolicyLAP private ROYALTY_POLICY_LAP; // keep private to avoid collision with `BaseIntegration`

    mapping(string frameworkName => uint256 frameworkId) internal frameworkIds;

    mapping(string policyName => uint256 globalPolicyId) internal policyIds;

    mapping(string policyName => RegisterUMLPolicyParams policy) internal policies;

    mapping(string policyFrameworkManagerName => address policyFrameworkManagerAddr) internal pfm;

    string[] internal emptyStringArray = new string[](0);

    function initLicensingHelper(
        address _accessController,
        address _ipAccountRegistry,
        address _licensingModule,
        address _royaltyModule,
        address _royaltyPolicy
    ) public {
        ACCESS_CONTROLLER = IAccessController(_accessController);
        IP_ACCOUNT_REGISTRY = IIPAccountRegistry(_ipAccountRegistry);
        LICENSING_MODULE = ILicensingModule(_licensingModule);
        ROYALTY_MODULE = IRoyaltyModule(_royaltyModule);
        ROYALTY_POLICY_LAP = IRoyaltyPolicyLAP(_royaltyPolicy);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        MODIFIERS: LICENSE FRAMEWORK (MANAGERS)
    //////////////////////////////////////////////////////////////////////////*/

    modifier withLFM_UML() {
        _deployLFM_UML();
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODIFIERS: POLICY
    //////////////////////////////////////////////////////////////////////////*/

    // modifier withUMLPolicy_Commercial_Derivative(
    //     UMLPolicyGenericParams memory gparams,
    //     UMLPolicyCommercialParams memory cparams,
    //     UMLPolicyDerivativeParams memory dparams
    // ) {
    //     UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"]);

    //     string memory pName = string(abi.encodePacked("uml_com_deriv_", gparams.policyName));
    //     policyIds[pName] = _pfm.registerPolicy(
    //         UMLPolicy({
    //             transferable: gparams.transferable,
    //             attribution: gparams.attribution,
    //             commercialUse: true,
    //             commercialAttribution: cparams.commercialAttribution,
    //             commercializerChecker: cparams.commercializerChecker,
    //             commercializerCheckerData: cparams.commercializerCheckerData,
    //             commercialRevShare: cparams.commercialRevShare,
    //             derivativesAllowed: true,
    //             derivativesAttribution: dparams.derivativesAttribution,
    //             derivativesApproval: dparams.derivativesApproval,
    //             derivativesReciprocal: dparams.derivativesReciprocal,
    //             derivativesRevShare: dparams.derivativesRevShare,
    //             territories: gparams.territories,
    //             contentRestrictions: gparams.contentRestrictions,
    //             distributionChannels: gparams.distributionChannels,
    //             royaltyPolicy: cparams.royaltyPolicy
    //         })
    //     );
    //     _;
    // }

    // modifier withUMLPolicy_Commerical_NonDerivative(
    //     UMLPolicyGenericParams memory gparams,
    //     UMLPolicyCommercialParams memory cparams
    // ) {
    //     UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"]);

    //     string memory pName = string(abi.encodePacked("uml_com_nonderiv_", gparams.policyName));
    //     policyIds[pName] = _pfm.registerPolicy(
    //         UMLPolicy({
    //             transferable: gparams.transferable,
    //             attribution: gparams.attribution,
    //             commercialUse: true,
    //             commercialAttribution: cparams.commercialAttribution,
    //             commercializerChecker: cparams.commercializerChecker,
    //             commercializerCheckerData: cparams.commercializerCheckerData,
    //             commercialRevShare: cparams.commercialRevShare,
    //             derivativesAllowed: false,
    //             derivativesAttribution: false,
    //             derivativesApproval: false,
    //             derivativesReciprocal: false,
    //             derivativesRevShare: 0,
    //             territories: gparams.territories,
    //             contentRestrictions: gparams.contentRestrictions,
    //             distributionChannels: gparams.distributionChannels,
    //             royaltyPolicy: cparams.royaltyPolicy
    //         })
    //     );
    //     _;
    // }

    // modifier withUMLPolicy_NonCommercial_Derivative(
    //     UMLPolicyGenericParams memory gparams,
    //     UMLPolicyDerivativeParams memory dparams
    // ) {
    //     UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"]);

    //     string memory pName = string(abi.encodePacked("uml_noncom_deriv_", gparams.policyName));
    //     policyIds[pName] = _pfm.registerPolicy(
    //         UMLPolicy({
    //             transferable: gparams.transferable,
    //             attribution: gparams.attribution,
    //             commercialUse: false,
    //             commercialAttribution: false,
    //             commercializerChecker: address(0),
    //             commercializerCheckerData: "",
    //             commercialRevShare: 0,
    //             derivativesAllowed: true,
    //             derivativesAttribution: dparams.derivativesAttribution,
    //             derivativesApproval: dparams.derivativesApproval,
    //             derivativesReciprocal: dparams.derivativesReciprocal,
    //             derivativesRevShare: dparams.derivativesRevShare,
    //             territories: gparams.territories,
    //             distributionChannels: gparams.distributionChannels,
    //             contentRestrictions: gparams.contentRestrictions,
    //             royaltyPolicy: address(0)
    //         })
    //     );
    //     _;
    // }

    // modifier withUMLPolicy_NonCommercial_NonDerivative(UMLPolicyGenericParams memory gparams) {
    //     UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"]);

    //     string memory pName = string(abi.encodePacked("uml_noncom_nonderiv_", gparams.policyName));
    //     policyIds[pName] = _pfm.registerPolicy(
    //         UMLPolicy({
    //             transferable: gparams.transferable,
    //             attribution: gparams.attribution,
    //             commercialUse: false,
    //             commercialAttribution: false,
    //             commercializerChecker: address(0),
    //             commercializerCheckerData: "",
    //             commercialRevShare: 0,
    //             derivativesAllowed: false,
    //             derivativesAttribution: false,
    //             derivativesApproval: false,
    //             derivativesReciprocal: false,
    //             derivativesRevShare: 0,
    //             territories: gparams.territories,
    //             contentRestrictions: gparams.contentRestrictions,
    //             distributionChannels: gparams.distributionChannels,
    //             royaltyPolicy: address(0)
    //         })
    //     );
    //     _;
    // }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _setUMLPolicyFrameworkManager() internal {
        UMLPolicyFrameworkManager umlPfm = new UMLPolicyFrameworkManager(
            address(ACCESS_CONTROLLER),
            address(IP_ACCOUNT_REGISTRY),
            address(LICENSING_MODULE),
            "UML_MINT_PAYMENT",
            "license Url"
        );
        pfm["uml"] = address(umlPfm);
        LICENSING_MODULE.registerPolicyFrameworkManager(address(umlPfm));
    }

    function _addUMLPolicy(
        string memory policyName,
        bool transferable,
        address royaltyPolicy,
        UMLPolicy memory policy
    ) internal {
        string memory pName = string(abi.encodePacked("uml_", policyName));
        policies[pName] = RegisterUMLPolicyParams({
            transferable: transferable,
            royaltyPolicy: royaltyPolicy,
            mintingFee: 0,
            mintingFeeToken: address(0),
            policy: policy
        });
        policyIds[pName] = UMLPolicyFrameworkManager(pfm["uml"]).registerPolicy(policies[pName]);
    }

    function _mapUMLPolicySimple(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal,
        uint32 commercialRevShare
    ) internal {
        string memory pName = string(abi.encodePacked("uml_", name));
        policies[pName] = RegisterUMLPolicyParams({
            transferable: true,
            // TODO: use mock or real based on condition
            royaltyPolicy: commercial ? address(ROYALTY_POLICY_LAP) : address(0),
            mintingFee: 0,
            mintingFeeToken: address(0),
            policy: UMLPolicy({
                attribution: true,
                commercialUse: commercial,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: commercial ? commercialRevShare : 0,
                derivativesAllowed: derivatives,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: reciprocal,
                territories: emptyStringArray,
                distributionChannels: emptyStringArray,
                contentRestrictions: emptyStringArray
            })
        });
    }

    function _addUMLPolicyFromMapping(string memory name, address umlFramework) internal returns (uint256) {
        string memory pName = string(abi.encodePacked("uml_", name));
        policyIds[pName] = UMLPolicyFrameworkManager(umlFramework).registerPolicy(policies[pName]);
        return policyIds[pName];
    }

    function _registerUMLPolicyFromMapping(string memory name) internal returns (uint256) {
        string memory pName = string(abi.encodePacked("uml_", name));
        policyIds[pName] = UMLPolicyFrameworkManager(pfm["uml"]).registerPolicy(policies[pName]);
        return policyIds[pName];
    }

    function _getMappedUmlPolicy(string memory name) internal view returns (UMLPolicy storage) {
        string memory pName = string(abi.encodePacked("uml_", name));
        return policies[pName].policy;
    }

    function _getMappedUmlParams(string memory name) internal view returns (RegisterUMLPolicyParams storage) {
        string memory pName = string(abi.encodePacked("uml_", name));
        return policies[pName];
    }

    function _getUmlPolicyId(string memory name) internal view returns (uint256) {
        string memory pName = string(abi.encodePacked("uml_", name));
        return policyIds[pName];
    }

    function _createMockPolicyFrameworkManager(
        bool supportVerifyLink,
        bool supportVerifyMint
    ) private returns (BasePolicyFrameworkManager) {
        return
            BasePolicyFrameworkManager(
                new MockPolicyFrameworkManager(
                    MockPolicyFrameworkConfig({
                        licensingModule: address(LICENSING_MODULE),
                        name: "mock",
                        licenseUrl: "license url",
                        royaltyPolicy: address(0xdeadbeef)
                    })
                )
            );
    }

    function _deployLFM_UML() internal {
        BasePolicyFrameworkManager _pfm = BasePolicyFrameworkManager(
            new UMLPolicyFrameworkManager(
                address(ACCESS_CONTROLLER),
                address(IP_ACCOUNT_REGISTRY),
                address(LICENSING_MODULE),
                "uml",
                "license Url"
            )
        );
        LICENSING_MODULE.registerPolicyFrameworkManager(address(_pfm));
        pfm["uml"] = address(_pfm);
    }
}
