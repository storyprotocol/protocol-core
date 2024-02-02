// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { UMLFrameworkErrors } from "contracts/lib/UMLFrameworkErrors.sol";
import { IUMLPolicyFrameworkManager, UMLPolicy, UMLRights } from "contracts/interfaces/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

import "forge-std/console2.sol";

contract UMLPolicyFrameworkCompatibilityTest is Test {
    MockAccessController public accessController = new MockAccessController();
    IPAccountRegistry public ipAccountRegistry;

    LicenseRegistry public registry;

    UMLPolicyFrameworkManager public umlFramework;

    MockERC721 nft = new MockERC721("MockERC721");

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipOwner = vm.addr(1);
    address public licenseHolder = address(0x101);
    string[] public emptyStringArray = new string[](0);
    uint256 public policyID;
    mapping(string => UMLPolicy) public policies;
    mapping(string => uint256) public policyIDs;

    modifier withPolicy(string memory name, bool commercial, bool derivatives) {
        policies[name] = UMLPolicy({
            attribution: true,
            transferable: true,
            commercialUse: commercial,
            commercialAttribution: false,
            commercializers: emptyStringArray,
            commercialRevShare: 0,
            derivativesAllowed: derivatives,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            derivativesRevShare: 0,
            territories: emptyStringArray,
            distributionChannels: emptyStringArray
        });
        policyIDs[name] = umlFramework.registerPolicy(policies[name]);
        _;
    }

    function setUp() public {
        ipAccountRegistry = new IPAccountRegistry(
            address(new ERC6551Registry()),
            address(accessController),
            address(new IPAccountImpl())
        );
        registry = new LicenseRegistry(address(accessController), address(ipAccountRegistry));
        umlFramework = new UMLPolicyFrameworkManager(
            address(accessController),
            address(registry),
            "UMLPolicyFrameworkManager",
            licenseUrl
        );
        registry.registerPolicyFrameworkManager(address(umlFramework));

        nft.mintId(ipOwner, 1);
        nft.mintId(ipOwner, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);
    }


    function test_addFirstPolicyToIpId_rightsUpdate()
        withPolicy("comm_deriv", true, true)
        public{
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyIDs["comm_deriv"]);
        UMLRights memory rights = umlFramework.getRights(ipId1);
        assertEq(rights.commercial, true);
        assertEq(rights.derivable, true);
        
    }

    function test_revert_incompatiblePolicy_rightsCommPolicyNonComm()
        withPolicy("non_comm_deriv", false, true)
        withPolicy("comm_deriv", true, true)
        public {
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyIDs["non_comm_deriv"]);
        vm.prank(ipOwner);
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_NewCommercialPolicyNotAccepted.selector);
        registry.addPolicyToIp(ipId1, policyIDs["comm_deriv"]);
    }

    function test_revert_incompatiblePolicy_rightsDerivPolocuNonDeriv()
        withPolicy("comm_deriv", true, true)
        withPolicy("comm_non_deriv", true, false)
        public {
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyIDs["comm_deriv"]);
        vm.prank(ipOwner);
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_NewDerivativesPolicyNotAccepted.selector);
        registry.addPolicyToIp(ipId1, policyIDs["comm_non_deriv"]);
    }
    /*
    function test_revert_firstReciprocal_nextPolicyNonReciprocal()
        withPolicy("reciprocal", true, true)
        withPolicy("non_reciprocal", true, true)
        public {
        policies["reciprocal"].reciprocal = true;
        policies["non_reciprocal"].reciprocal = false;
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyIDs["reciprocal"]);
        vm.prank(ipOwner);
        vm.expectRevert(UMLFrameworkErrors.UMLPolicyFrameworkManager_ReciprocaConfiglNegatesNewPolicy.selector);
        registry.addPolicyToIp(ipId1, policyIDs["non_reciprocal"]);
    }
    */


}
