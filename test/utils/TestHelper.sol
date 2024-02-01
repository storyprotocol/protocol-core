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
            address(licenseRegistry),
            address(royaltyModule),
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
        policyIds[pName] = UMLPolicyFrameworkManager(pfms["uml"].addr).registerPolicy(
            UMLPolicy({
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
                royaltyPolicy: cparams.royaltyPolicy
            })
        );
    }

    function _getIpId(MockERC721 mnft, uint256 tokenId) internal view returns (address ipId) {
        return _getIpId(address(mnft), tokenId);
    }

    function _getIpId(address mnft, uint256 tokenId) internal view returns (address ipId) {
        return ipAccountRegistry.ipAccount(block.chainid, mnft, tokenId);
    }
}
