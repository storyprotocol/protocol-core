// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
// solhint-disable no-console
import { console2 } from "forge-std/console2.sol"; // console to indicate setUp call.
import { Test } from "forge-std/Test.sol";

// contracts
import { RegisterUMLPolicyParams } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// test
// solhint-disable-next-line max-line-length
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { DeployHelper } from "test/foundry/utils/DeployHelper.sol";

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
    uint256 internal constant accountH = 8;
    uint256 internal constant accountI = 9;
    uint256 internal constant accountJ = 10;

    address internal deployer;
    address internal arbitrationRelayer;
    address internal ipAccount1;
    address internal ipAccount2;
    address internal ipAccount3;
    address internal ipAccount4;
    address internal ipAccount5;
    address internal ipAccount6;
    address internal ipAccount7;

    MockERC721 internal nft;
    uint256[] internal nftIds;

    mapping(string policyFrameworkManagerName => PolicyFrameworkManagerData) internal pfms;

    mapping(string policyName => uint256 policyId) internal policyIds;
    mapping(string => RegisterUMLPolicyParams) internal policies;

    string[] internal emptyStringArray = new string[](0);

    function setUp() public virtual {
        // solhint-disable no-console
        console2.log("TestHelper.setUp");
        deployer = vm.addr(accountA);
        arbitrationRelayer = vm.addr(accountC);
        ipAccount1 = vm.addr(accountD);
        ipAccount2 = vm.addr(accountE);
        ipAccount3 = vm.addr(accountF);
        ipAccount4 = vm.addr(accountG);
        ipAccount5 = vm.addr(accountH);
        ipAccount6 = vm.addr(accountI);
        ipAccount7 = vm.addr(accountJ);

        deploy();

        // vm.label(deployer, "deployer");
        // vm.label(arbitrationRelayer, "arbitrationRelayer");
        // vm.label(ipAccount1, "ipAccount1");
        // vm.label(ipAccount2, "ipAccount2");
        // vm.label(ipAccount3, "ipAccount3");
        // vm.label(ipAccount4, "ipAccount4");
    }

    function _setUMLPolicyFrameworkManager() internal {
        UMLPolicyFrameworkManager umlPfm = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAssetRegistry),
            address(licensingModule),
            "UML_MINT_PAYMENT",
            "license Url"
        );
        licensingModule.registerPolicyFrameworkManager(address(umlPfm));

        pfms["uml"] = PolicyFrameworkManagerData({ name: "uml", addr: address(umlPfm) });
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
            policy: policy
        });
        policyIds[pName] = UMLPolicyFrameworkManager(pfms["uml"].addr).registerPolicy(policies[pName]);
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
            royaltyPolicy: address(mockRoyaltyPolicyLS),
            policy: UMLPolicy({
                attribution: true,
                commercialUse: commercial,
                commercialAttribution: false,
                commercializers: emptyStringArray,
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

    function _getIpId(MockERC721 mnft, uint256 tokenId) internal view returns (address ipId) {
        return _getIpId(address(mnft), tokenId);
    }

    function _getIpId(address mnft, uint256 tokenId) internal view returns (address ipId) {
        return ipAccountRegistry.ipAccount(block.chainid, mnft, tokenId);
    }
}
