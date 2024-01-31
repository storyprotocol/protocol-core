// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract
import { AccessController } from "contracts/AccessController.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";

// test
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig, MockPolicy } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
import { MintPaymentPolicyFrameworkManager, MintPaymentPolicy } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";

enum PFMType {
    UML,
    MintPayment,
    MockGeneric
}

struct PFMData {
    PFMType pfmType;
    uint256 pfmId;
    address addr;
}

struct UMLPolicyGenericParams {
    string policyName;
    bool attribution;
    bool transferable;
    string[] territories;
    string[] distributionChannels;
}

struct UMLPolicyCommercialParams {
    bool commercialAttribution;
    string[] commercializers;
    uint256 commercialRevShare;
}

struct UMLPolicyDerivativeParams {
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    uint256 derivativesRevShare;
}

contract Integration_Shared_LicenseFramework_and_Policy {
    mapping(string frameworkName => uint256 frameworkId) internal frameworkIds;

    mapping(string policyName => uint256 globalPolicyId) internal policyIds;

    mapping(string policyFrameworkManagerName => PFMData) internal pfm;

    LicenseRegistry private licenseRegistry; // keep private to avoid collision with `BaseIntegration`

    AccessController private accessController; // keep private to avoid collision with `BaseIntegration`

    function initLicenseFrameworkAndPolicy(
        AccessController accessController_,
        LicenseRegistry licenseRegistry_
    ) public {
        accessController = accessController_;
        licenseRegistry = licenseRegistry_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                        MODIFIERS: LICENSE FRAMEWORK (MANAGERS)
    //////////////////////////////////////////////////////////////////////////*/

    modifier withLFM_UML() {
        BasePolicyFrameworkManager _pfm = BasePolicyFrameworkManager(
            new UMLPolicyFrameworkManager(address(accessController), address(licenseRegistry), "license Url")
        );
        pfm["uml"] = PFMData({ pfmType: PFMType.UML, pfmId: _pfm.register(), addr: address(_pfm) });
        _;
    }

    modifier withLFM_MintPayment(ERC20 erc20, uint256 paymentWithoutDecimals) {
        BasePolicyFrameworkManager _pfm = BasePolicyFrameworkManager(
            new MintPaymentPolicyFrameworkManager(
                address(licenseRegistry),
                "license url",
                address(erc20),
                paymentWithoutDecimals * 10 ** erc20.decimals() // `paymentWithoutDecimals` amount per license mint
            )
        );
        pfm["mint_payment"] = PFMData({ pfmType: PFMType.MintPayment, pfmId: _pfm.register(), addr: address(_pfm) });
        _;
    }

    modifier withLFM_MockOnAll() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(true, true, true);
        pfm["mock_on_all"] = PFMData({ pfmType: PFMType.MockGeneric, pfmId: _pfm.register(), addr: address(_pfm) });
        _;
    }

    modifier withLFM_MockOnLink() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(true, false, false);
        pfm["mock_on_link"] = PFMData({ pfmType: PFMType.MockGeneric, pfmId: _pfm.register(), addr: address(_pfm) });
        _;
    }

    modifier withLFM_MockOnMint() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(false, true, false);
        pfm["mock_on_mint"] = PFMData({ pfmType: PFMType.MockGeneric, pfmId: _pfm.register(), addr: address(_pfm) });
        _;
    }

    modifier withLFM_MockOnTransfer() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(false, false, true);
        pfm["mock_on_transfer"] = PFMData({
            pfmType: PFMType.MockGeneric,
            pfmId: _pfm.register(),
            addr: address(_pfm)
        });
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
        policyIds[pName] = _pfm.addPolicy(
            UMLPolicy({
                attribution: gparams.attribution,
                transferable: gparams.transferable,
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
                distributionChannels: gparams.distributionChannels
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
        policyIds[pName] = _pfm.addPolicy(
            UMLPolicy({
                attribution: gparams.attribution,
                transferable: gparams.transferable,
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
                distributionChannels: gparams.distributionChannels
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
        policyIds[pName] = _pfm.addPolicy(
            UMLPolicy({
                attribution: gparams.attribution,
                transferable: gparams.transferable,
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
                distributionChannels: gparams.distributionChannels
            })
        );
        _;
    }

    modifier withUMLPolicy_NonCommercial_NonDerivative(UMLPolicyGenericParams memory gparams) {
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"].addr);

        string memory pName = string(abi.encodePacked("uml_noncom_nonderiv_", gparams.policyName));
        policyIds[pName] = _pfm.addPolicy(
            UMLPolicy({
                attribution: gparams.attribution,
                transferable: gparams.transferable,
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
                distributionChannels: gparams.distributionChannels
            })
        );
        _;
    }

    modifier withMintPaymentPolicy(string memory policyName, bool mustBeTrue) {
        // NOTE: If `mustBeTrue` = true, then the policy will return `true` on successful payment.
        //       Ttherwise (false), the policy will return `false` even on successful payment.
        MintPaymentPolicyFrameworkManager _pfm = MintPaymentPolicyFrameworkManager(pfm["mint_payment"].addr);

        string memory pName = string(abi.encodePacked("mint_payment_", policyName));
        policyIds[pName] = _pfm.addPolicy(MintPaymentPolicy({ mustBeTrue: mustBeTrue }));
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _createMockPolicyFrameworkManager(
        bool supportVerifyLink,
        bool supportVerifyMint,
        bool supportVerifyTransfer
    ) private returns (BasePolicyFrameworkManager) {
        return
            BasePolicyFrameworkManager(
                new MockPolicyFrameworkManager(
                    MockPolicyFrameworkConfig({
                        licenseRegistry: address(licenseRegistry),
                        licenseUrl: "license url",
                        supportVerifyLink: supportVerifyLink,
                        supportVerifyMint: supportVerifyMint,
                        supportVerifyTransfer: supportVerifyTransfer
                    })
                )
            );
    }
}
