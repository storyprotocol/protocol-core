// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract
import { AccessController } from "contracts/AccessController.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";

// test
// solhint-disable-next-line max-line-length
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
// solhint-disable-next-line max-line-length
import { MintPaymentPolicyFrameworkManager, MintPaymentPolicy } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";
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

struct UMLPolicyGenericParams {
    string policyName;
    bool attribution;
    bool transferable;
    string[] territories;
    string[] distributionChannels;
    string[] contentRestrictions;
}

struct UMLPolicyCommercialParams {
    bool commercialAttribution;
    string[] commercializers;
    uint32 commercialRevShare;
    address royaltyPolicy;
}

struct UMLPolicyDerivativeParams {
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    uint32 derivativesRevShare;
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

    modifier withLFM_MintPayment(ERC20 erc20, uint256 paymentWithoutDecimals) {
        BasePolicyFrameworkManager _pfm = BasePolicyFrameworkManager(
            new MintPaymentPolicyFrameworkManager(
                address(licensingModule),
                address(mockRoyaltyPolicyLS),
                "mint_payment",
                "license url",
                address(erc20),
                paymentWithoutDecimals * 10 ** erc20.decimals() // `paymentWithoutDecimals` amount per license mint
            )
        );
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mint_payment"] = PFMData({ pfmType: PFMType.MintPayment, addr: address(_pfm) });
        _;
    }

    modifier withLFM_MockOnAll() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(true, true);
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mock_on_all"] = PFMData({ pfmType: PFMType.MockGeneric, addr: address(_pfm) });
        _;
    }

    modifier withLFM_MockOnLink() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(true, false);
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mock_on_link"] = PFMData({ pfmType: PFMType.MockGeneric, addr: address(_pfm) });
        _;
    }

    modifier withLFM_MockOnMint() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(false, true);
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mock_on_mint"] = PFMData({ pfmType: PFMType.MockGeneric, addr: address(_pfm) });
        _;
    }

    modifier withLFM_MockOnTransfer() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(false, false);
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mock_on_transfer"] = PFMData({ pfmType: PFMType.MockGeneric, addr: address(_pfm) });
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODIFIERS: POLICY
    //////////////////////////////////////////////////////////////////////////*/

    modifier withUMLPolicy_Commerical_Derivative(
        UMLPolicyGenericParams memory gparams,
        UMLPolicyCommercialParams memory cparams,
        UMLPolicyDerivativeParams memory dparams
    ) {
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"].addr);

        string memory pName = string(abi.encodePacked("uml_com_deriv_", gparams.policyName));
        policyIds[pName] = _pfm.registerPolicy(
            UMLPolicy({
                transferable: gparams.transferable,
                attribution: gparams.attribution,
                commercialUse: true,
                commercialAttribution: cparams.commercialAttribution,
                commercializers: cparams.commercializers,
                commercialRevShare: cparams.commercialRevShare,
                derivativesAllowed: true,
                derivativesAttribution: dparams.derivativesAttribution,
                derivativesApproval: dparams.derivativesApproval,
                derivativesReciprocal: dparams.derivativesReciprocal,
                derivativesRevShare: dparams.derivativesRevShare,
                territories: gparams.territories,
                contentRestrictions: gparams.contentRestrictions,
                distributionChannels: gparams.distributionChannels,
                royaltyPolicy: cparams.royaltyPolicy
            })
        );
        _;
    }

    modifier withUMLPolicy_Commerical_NonDerivative(
        UMLPolicyGenericParams memory gparams,
        UMLPolicyCommercialParams memory cparams
    ) {
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"].addr);

        string memory pName = string(abi.encodePacked("uml_com_nonderiv_", gparams.policyName));
        policyIds[pName] = _pfm.registerPolicy(
            UMLPolicy({
                transferable: gparams.transferable,
                attribution: gparams.attribution,
                commercialUse: true,
                commercialAttribution: cparams.commercialAttribution,
                commercializers: cparams.commercializers,
                commercialRevShare: cparams.commercialRevShare,
                derivativesAllowed: false,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativesRevShare: 0,
                territories: gparams.territories,
                contentRestrictions: gparams.contentRestrictions,
                distributionChannels: gparams.distributionChannels,
                royaltyPolicy: cparams.royaltyPolicy
            })
        );
        _;
    }

    modifier withUMLPolicy_NonCommercial_Derivative(
        UMLPolicyGenericParams memory gparams,
        UMLPolicyDerivativeParams memory dparams
    ) {
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"].addr);

        string memory pName = string(abi.encodePacked("uml_noncom_deriv_", gparams.policyName));
        policyIds[pName] = _pfm.registerPolicy(
            UMLPolicy({
                transferable: gparams.transferable,
                attribution: gparams.attribution,
                commercialUse: false,
                commercialAttribution: false,
                commercializers: new string[](0),
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: dparams.derivativesAttribution,
                derivativesApproval: dparams.derivativesApproval,
                derivativesReciprocal: dparams.derivativesReciprocal,
                derivativesRevShare: dparams.derivativesRevShare,
                territories: gparams.territories,
                distributionChannels: gparams.distributionChannels,
                contentRestrictions: gparams.contentRestrictions,
                royaltyPolicy: address(0)
            })
        );
        _;
    }

    modifier withUMLPolicy_NonCommercial_NonDerivative(UMLPolicyGenericParams memory gparams) {
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"].addr);

        string memory pName = string(abi.encodePacked("uml_noncom_nonderiv_", gparams.policyName));
        policyIds[pName] = _pfm.registerPolicy(
            UMLPolicy({
                transferable: gparams.transferable,
                attribution: gparams.attribution,
                commercialUse: false,
                commercialAttribution: false,
                commercializers: new string[](0),
                commercialRevShare: 0,
                derivativesAllowed: false,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativesRevShare: 0,
                territories: gparams.territories,
                contentRestrictions: gparams.contentRestrictions,
                distributionChannels: gparams.distributionChannels,
                royaltyPolicy: address(0)
            })
        );
        _;
    }

    modifier withMintPaymentPolicy(string memory policyName, bool mustBeTrue) {
        // NOTE: If `mustBeTrue` = true, then the policy will return `true` on successful payment.
        //       Ttherwise (false), the policy will return `false` even on successful payment.
        MintPaymentPolicyFrameworkManager _pfm = MintPaymentPolicyFrameworkManager(pfm["mint_payment"].addr);

        string memory pName = string(abi.encodePacked("mint_payment_", policyName));
        policyIds[pName] = _pfm.registerPolicy(MintPaymentPolicy({ mustBeTrue: mustBeTrue }));
        _;
    }

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
                        supportVerifyLink: supportVerifyLink,
                        supportVerifyMint: supportVerifyMint,
                        royaltyPolicy: address(0xdeadbeef)
                    })
                )
            );
    }
}
