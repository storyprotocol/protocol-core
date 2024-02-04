// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";

// contracts
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// test
import { UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/integration/shared/LicenseHelper.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { DeployHelper } from "test/utils/DeployHelper.sol";

struct PolicyFrameworkManagerData {
    string name;
    address addr;
}

contract TestHelper is Test, DeployHelper {
    uint256 internal constant accountA = 1;
    uint256 internal constant accountB = 2;
    uint256 internal constant accountC = 3;
    uint256 internal constant accountD = 4;
    uint256 internal constant accountE = 5;
    uint256 internal constant accountF = 6;
    uint256 internal constant accountG = 7;

    address internal deployer;
    address internal arbitrationRelayer;
    address internal ipAccount1;
    address internal ipAccount2;
    address internal ipAccount3;
    address internal ipAccount4;

    MockERC721 internal nft;
    uint256[] internal nftIds;

    mapping(string policyFrameworkManagerName => PolicyFrameworkManagerData) internal pfms;

    mapping(string policyName => uint256 policyId) internal policyIds;
    mapping(string => UMLPolicy) internal policies;

    string[] internal emptyStringArray = new string[](0);
    address mockRoyaltyPolicy = address(0x555);


    function setUp() public virtual {
        deployer = vm.addr(accountA);
        arbitrationRelayer = vm.addr(accountC);
        ipAccount1 = vm.addr(accountD);
        ipAccount2 = vm.addr(accountE);
        ipAccount3 = vm.addr(accountF);
        ipAccount4 = vm.addr(accountG);

        deploy();

        vm.label(deployer, "deployer");
        vm.label(arbitrationRelayer, "arbitrationRelayer");
        vm.label(ipAccount1, "ipAccount1");
        vm.label(ipAccount2, "ipAccount2");
        vm.label(ipAccount3, "ipAccount3");
        vm.label(ipAccount4, "ipAccount4");
    }

    function _setUMLPolicyFrameworkManager() internal {
        UMLPolicyFrameworkManager umlPfm = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry),
            "UML_MINT_PAYMENT",
            "license Url"
        );
        licenseRegistry.registerPolicyFrameworkManager(address(umlPfm));

        pfms["uml"] = PolicyFrameworkManagerData({ name: "uml", addr: address(umlPfm) });
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
            attribution: gparams.attribution,
            transferable: gparams.transferable,
            commercialUse: commercialUse,
            commercialAttribution: cparams.commercialAttribution,
            commercializers: cparams.commercializers,
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
        policyIds[pName] = UMLPolicyFrameworkManager(pfms["uml"].addr)
        .registerPolicy(policies[pName]);
    }

    function _mapUMLPolicySimple(
        string memory name,
        bool commercial,
        bool derivatives,
        bool reciprocal
    ) internal {
        string memory pName = string(abi.encodePacked("uml_", name));
        policies[pName] = UMLPolicy({
            attribution: true,
            transferable: true,
            commercialUse: commercial,
            commercialAttribution: false,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: derivatives,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: reciprocal,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray,
            contentRestrictions: emptyStringArray,
            royaltyPolicy: mockRoyaltyPolicy
        });
    }

    function _addUMLPolicyFromMapping(string memory name, address umlFramework) internal returns (uint256){
        string memory pName = string(abi.encodePacked("uml_", name));
        policyIds[pName] = UMLPolicyFrameworkManager(umlFramework).registerPolicy(policies[pName]);
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


    function _getIpId(MockERC721 mnft, uint256 tokenId) internal view returns (address ipId) {
        return _getIpId(address(mnft), tokenId);
    }

    function _getIpId(address mnft, uint256 tokenId) internal view returns (address ipId) {
        return ipAccountRegistry.ipAccount(block.chainid, mnft, tokenId);
    }
}
