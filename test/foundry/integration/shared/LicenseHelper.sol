// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract
import { AccessController } from "contracts/AccessController.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager, UMLPolicy, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";

// test
// solhint-disable-next-line max-line-length
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
// solhint-disable-next-line max-line-length
import { MockRoyaltyPolicyLS } from "test/foundry/mocks/MockRoyaltyPolicyLS.sol";

enum PFMType {
    UML,
    MintPayment,
    MockGeneric
}

struct PFMData {
    PFMType pfmType;
    address addr;
}

contract Integration_Shared_LicensingHelper {
    mapping(string frameworkName => uint256 frameworkId) internal frameworkIds;

    mapping(string policyName => uint256 globalPolicyId) internal policyIds;

    mapping(string policyFrameworkManagerName => PFMData) internal pfm;

    LicensingModule private licensingModule; // keep private to avoid collision with `BaseIntegration`

    AccessController private accessController; // keep private to avoid collision with `BaseIntegration`

    IPAccountRegistry private ipAccountRegistry; // keep private to avoid collision with `BaseIntegration`

    RoyaltyModule private royaltyModule; // keep private to avoid collision with `BaseIntegration`

    MockRoyaltyPolicyLS private mockRoyaltyPolicyLS; // keep private to avoid collision with `BaseIntegration`

    function initLicenseFrameworkAndPolicy(
        AccessController accessController_,
        IPAccountRegistry ipAccountRegistry_,
        LicensingModule licensingModule_,
        RoyaltyModule royaltyModule_,
        MockRoyaltyPolicyLS mockRoyaltyPolicyLS_
    ) public {
        accessController = accessController_;
        ipAccountRegistry = ipAccountRegistry_;
        licensingModule = licensingModule_;
        royaltyModule = royaltyModule_;
        mockRoyaltyPolicyLS = mockRoyaltyPolicyLS_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        MODIFIERS: LICENSE FRAMEWORK (MANAGERS)
    //////////////////////////////////////////////////////////////////////////*/

    modifier withLFM_UML() {
        BasePolicyFrameworkManager _pfm = BasePolicyFrameworkManager(
            new UMLPolicyFrameworkManager(
                address(accessController),
                address(ipAccountRegistry),
                address(licensingModule),
                "uml",
                "license Url"
            )
        );
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["uml"] = PFMData({ pfmType: PFMType.UML, addr: address(_pfm) });
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODIFIERS: POLICY
    //////////////////////////////////////////////////////////////////////////*/

    // modifier withUMLPolicy_Commerical_Derivative(RegisterUMLPolicyParams memory params) {
    //     UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"].addr);

    //     string memory pName = string(abi.encodePacked("uml_com_deriv_", gparams.policyName));
    //     policyIds[pName] = _pfm.registerPolicy(
    //         gparams.transferable,
    //         cparams.royaltyPolicy,
    //         UMLPolicy({
    //             attribution: gparams.attribution,
    //             commercialUse: true,
    //             commercialAttribution: cparams.commercialAttribution,
    //             commercializers: cparams.commercializers,
    //             commercialRevShare: cparams.commercialRevShare,
    //             derivativesAllowed: true,
    //             derivativesAttribution: dparams.derivativesAttribution,
    //             derivativesApproval: dparams.derivativesApproval,
    //             derivativesReciprocal: dparams.derivativesReciprocal,
    //             territories: gparams.territories,
    //             distributionChannels: gparams.distributionChannels,
    //             contentRestrictions: gparams.contentRestrictions
    //         })
            
    //     );
    //     _;
    // }

    // modifier withUMLPolicy_NonCommercial_Derivative(
    //     UMLPolicyGenericParams memory gparams,
    //     UMLPolicyDerivativeParams memory dparams
    // ) {
    //     UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"].addr);

    //     string memory pName = string(abi.encodePacked("uml_noncom_deriv_", gparams.policyName));
    //     policyIds[pName] = _pfm.registerPolicy(
    //         UMLPolicy({
    //             transferable: gparams.transferable,
    //             attribution: gparams.attribution,
    //             commercialUse: false,
    //             commercialAttribution: false,
    //             commercializers: new string[](0),
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
    //     UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"].addr);

    //     string memory pName = string(abi.encodePacked("uml_noncom_nonderiv_", gparams.policyName));
    //     policyIds[pName] = _pfm.registerPolicy(
    //         UMLPolicy({
    //             transferable: gparams.transferable,
    //             attribution: gparams.attribution,
    //             commercialUse: false,
    //             commercialAttribution: false,
    //             commercializers: new string[](0),
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

    function _createMockPolicyFrameworkManager(
        bool supportVerifyLink,
        bool supportVerifyMint
    ) private returns (BasePolicyFrameworkManager) {
        return
            BasePolicyFrameworkManager(
                new MockPolicyFrameworkManager(
                    MockPolicyFrameworkConfig({
                        licensingModule: address(licensingModule),
                        name: "mock",
                        licenseUrl: "license url",
                        royaltyPolicy: address(0xdeadbeef)
                    })
                )
            );
    }
}
