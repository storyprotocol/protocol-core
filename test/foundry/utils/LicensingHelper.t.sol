// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract
import { IAccessController } from "../../../contracts/interfaces/IAccessController.sol";
import { IIPAccountRegistry } from "../../../contracts/interfaces/registries/IIPAccountRegistry.sol";
import { ILicensingModule } from "../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IRoyaltyModule } from "../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "../../../contracts/interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { BasePolicyFrameworkManager } from "../../../contracts/modules/licensing/BasePolicyFrameworkManager.sol";
// solhint-disable-next-line max-line-length
import { UMLPolicyFrameworkManager, UMLPolicy } from "../../../contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// test
// solhint-disable-next-line max-line-length
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
// solhint-disable-next-line max-line-length
import { MintPaymentPolicyFrameworkManager, MintPaymentPolicy } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";

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
    address commercializerChecker;
    bytes commercializerCheckerData;
    uint32 commercialRevShare;
    address royaltyPolicy;
}

struct UMLPolicyDerivativeParams {
    bool derivativesAttribution;
    bool derivativesApproval;
    bool derivativesReciprocal;
    uint32 derivativesRevShare;
}

contract LicensingHelper {
    ILicensingModule private licensingModule; // keep private to avoid collision with `BaseIntegration`

    IAccessController private accessController; // keep private to avoid collision with `BaseIntegration`

    IIPAccountRegistry private ipAccountRegistry; // keep private to avoid collision with `BaseIntegration`

    IRoyaltyModule private royaltyModule; // keep private to avoid collision with `BaseIntegration`

    IRoyaltyPolicy private royaltyPolicy; // keep private to avoid collision with `BaseIntegration`

    mapping(string frameworkName => uint256 frameworkId) internal frameworkIds;

    mapping(string policyName => uint256 globalPolicyId) internal policyIds;

    mapping(string policyName => UMLPolicy policy) internal policies;

    mapping(string policyFrameworkManagerName => address policyFrameworkManagerAddr) internal pfm;

    string[] internal emptyStringArray = new string[](0);

    function initLicensingHelper(
        address _accessController,
        address _ipAccountRegistry,
        address _licensingModule,
        address _royaltyModule,
        address _royaltyPolicy
    ) public {
        accessController = IAccessController(_accessController);
        ipAccountRegistry = IIPAccountRegistry(_ipAccountRegistry);
        licensingModule = ILicensingModule(_licensingModule);
        royaltyModule = IRoyaltyModule(_royaltyModule);
        royaltyPolicy = IRoyaltyPolicy(_royaltyPolicy);
    }

    /*//////////////////////////////////////////////////////////////////////////
                        MODIFIERS: LICENSE FRAMEWORK (MANAGERS)
    //////////////////////////////////////////////////////////////////////////*/

    modifier withLFM_UML() {
        _deployLFM_UML();
        _;
    }

    modifier withLFM_MintPayment(ERC20 erc20, uint256 paymentWithoutDecimals) {
        BasePolicyFrameworkManager _pfm = BasePolicyFrameworkManager(
            new MintPaymentPolicyFrameworkManager(
                address(licensingModule),
                address(royaltyPolicy),
                "mint_payment",
                "license url",
                address(erc20),
                paymentWithoutDecimals * 10 ** erc20.decimals() // `paymentWithoutDecimals` amount per license mint
            )
        );
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mint_payment"] = address(_pfm);
        _;
    }

    modifier withLFM_MockOnAll() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(true, true);
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mock_on_all"] = address(_pfm);
        _;
    }

    modifier withLFM_MockOnLink() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(true, false);
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mock_on_link"] = address(_pfm);
        _;
    }

    modifier withLFM_MockOnMint() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(false, true);
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mock_on_mint"] = address(_pfm);
        _;
    }

    modifier withLFM_MockOnTransfer() {
        BasePolicyFrameworkManager _pfm = _createMockPolicyFrameworkManager(false, false);
        licensingModule.registerPolicyFrameworkManager(address(_pfm));
        pfm["mock_on_transfer"] = address(_pfm);
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                MODIFIERS: POLICY
    //////////////////////////////////////////////////////////////////////////*/

    modifier withUMLPolicy_Commercial_Derivative(
        UMLPolicyGenericParams memory gparams,
        UMLPolicyCommercialParams memory cparams,
        UMLPolicyDerivativeParams memory dparams
    ) {
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"]);

        string memory pName = string(abi.encodePacked("uml_com_deriv_", gparams.policyName));
        policyIds[pName] = _pfm.registerPolicy(
            UMLPolicy({
                transferable: gparams.transferable,
                attribution: gparams.attribution,
                commercialUse: true,
                commercialAttribution: cparams.commercialAttribution,
                commercializerChecker: cparams.commercializerChecker,
                commercializerCheckerData: cparams.commercializerCheckerData,
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
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"]);

        string memory pName = string(abi.encodePacked("uml_com_nonderiv_", gparams.policyName));
        policyIds[pName] = _pfm.registerPolicy(
            UMLPolicy({
                transferable: gparams.transferable,
                attribution: gparams.attribution,
                commercialUse: true,
                commercialAttribution: cparams.commercialAttribution,
                commercializerChecker: cparams.commercializerChecker,
                commercializerCheckerData: cparams.commercializerCheckerData,
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
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"]);

        string memory pName = string(abi.encodePacked("uml_noncom_deriv_", gparams.policyName));
        policyIds[pName] = _pfm.registerPolicy(
            UMLPolicy({
                transferable: gparams.transferable,
                attribution: gparams.attribution,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
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
        UMLPolicyFrameworkManager _pfm = UMLPolicyFrameworkManager(pfm["uml"]);

        string memory pName = string(abi.encodePacked("uml_noncom_nonderiv_", gparams.policyName));
        policyIds[pName] = _pfm.registerPolicy(
            UMLPolicy({
                transferable: gparams.transferable,
                attribution: gparams.attribution,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
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
        MintPaymentPolicyFrameworkManager _pfm = MintPaymentPolicyFrameworkManager(pfm["mint_payment"]);

        string memory pName = string(abi.encodePacked("mint_payment_", policyName));
        policyIds[pName] = _pfm.registerPolicy(MintPaymentPolicy({ mustBeTrue: mustBeTrue }));
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _setUMLPolicyFrameworkManager() internal {
        UMLPolicyFrameworkManager umlPfm = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "UML_MINT_PAYMENT",
            "license Url"
        );
        pfm["uml"] = address(umlPfm);
        licensingModule.registerPolicyFrameworkManager(address(umlPfm));
    }

    function _mapUMLPolicySimple(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal,
        uint32 commercialRevShare,
        uint32 derivativesRevShare
    ) internal {
        string memory pName = string(abi.encodePacked("uml_", name));
        policies[pName] = UMLPolicy({
            transferable: true,
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
            derivativesRevShare: derivatives ? derivativesRevShare : 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: address(royaltyPolicy)
        });
    }

    function _addUMLPolicy(
        bool commercialUse,
        bool derivativesAllowed,
        UMLPolicyGenericParams memory gparams,
        UMLPolicyCommercialParams memory cparams,
        UMLPolicyDerivativeParams memory dparams
    ) internal {
        string memory pName = string(abi.encodePacked("uml_", gparams.policyName));
        policies[pName] = UMLPolicy({
            transferable: gparams.transferable,
            attribution: gparams.attribution,
            commercialUse: commercialUse,
            commercialAttribution: cparams.commercialAttribution,
            commercializerChecker: cparams.commercializerChecker,
            commercializerCheckerData: cparams.commercializerCheckerData,
            commercialRevShare: cparams.commercialRevShare,
            derivativesAllowed: derivativesAllowed,
            derivativesAttribution: dparams.derivativesAttribution,
            derivativesApproval: dparams.derivativesApproval,
            derivativesReciprocal: dparams.derivativesReciprocal,
            derivativesRevShare: dparams.derivativesRevShare,
            territories: gparams.territories,
            distributionChannels: gparams.distributionChannels,
            contentRestrictions: gparams.contentRestrictions,
            royaltyPolicy: cparams.royaltyPolicy
        });
        policyIds[pName] = UMLPolicyFrameworkManager(pfm["uml"]).registerPolicy(policies[pName]);
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

    function _deployLFM_UML() internal {
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
        pfm["uml"] = address(_pfm);
    }
}
