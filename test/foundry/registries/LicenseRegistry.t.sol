// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// contracts
import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig, MockPolicy }
    from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { AccessController } from "contracts/AccessController.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";

// External
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";


contract LicenseRegistryTest is Test {
    using Strings for *;
    using ShortStrings for *;

    AccessController public accessController;
    IPAccountRegistry public ipAccountRegistry;
    Governance public governance;
    ERC6551Registry public erc6551Registry;
    IPAccountImpl public implementation;
    IModuleRegistry public moduleRegistry;

    LicenseRegistry public registry;
    Licensing.PolicyFramework public framework;

    MockPolicyFrameworkManager public module1;
    UMLPolicyFrameworkManager public umlManager;

    MockERC721 nft = new MockERC721("MockERC721");

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipOwner = vm.addr(1);
    address public licenseHolder = address(0x101);

    function setUp() public {
        ipAccountRegistry = new IPAccountRegistry(
            address(new ERC6551Registry()),
            address(accessController),
            address(new IPAccountImpl())
        );

        governance = new Governance(address(this));
        accessController = new AccessController(address(governance));
        erc6551Registry = new ERC6551Registry();
        implementation = new IPAccountImpl();
        ipAccountRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(implementation)
        );
        moduleRegistry = new ModuleRegistry(address(governance));
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));

        registry = new LicenseRegistry(address(accessController), address(ipAccountRegistry));
        moduleRegistry.registerModule("LICENSE_REGISTRY", address(registry));
        module1 = new MockPolicyFrameworkManager(MockPolicyFrameworkConfig({
            licenseRegistry: address(registry),
            licenseUrl: licenseUrl,
            supportVerifyLink: true,
            supportVerifyMint: true,
            supportVerifyTransfer: true
        }));
        umlManager = new UMLPolicyFrameworkManager(
            address(accessController),
            address(registry),
            licenseUrl
        );

        nft.mintId(ipOwner, 1);
        nft.mintId(ipOwner, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(
            block.chainid,
            address(nft),
            1
        );
        ipId2 = ipAccountRegistry.registerIpAccount(
            block.chainid,
            address(nft),
            2
        );
    }

    // TODO: add parameter config for initial framework for 100% test
    modifier withFrameworkParams() {
        module1.register();
        _;
    }

    function _createPolicy() internal pure returns (Licensing.Policy memory pol) {
        pol = Licensing.Policy({
            policyFrameworkId: 1,
            data: abi.encode(
                MockPolicy({
                    returnVerifyLink: true,
                    returnVerifyMint: true,
                    returnVerifyTransfer: true
                })
            )
        });
        return pol;
    }

    function test_LicenseRegistry_addLicenseFramework() public {
        uint256 fwId = module1.register();
        assertEq(fwId, 1, "not incrementing fw id");
        assertTrue(licenseUrl.equal(registry.frameworkUrl(fwId)), "licenseUrl not set");
        assertEq(registry.totalFrameworks(), 1, "totalFrameworks not incremented");
        Licensing.PolicyFramework memory storedFw = registry.framework(fwId);
        assertEq(storedFw.licenseUrl, licenseUrl, "licenseUrl not equal");
        assertEq(storedFw.policyFramework, address(module1), "policyFramework not equal");
    }

    function test_LicenseRegistry_addPolicy() public {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 polId = registry.addPolicy(policy);
        assertEq(polId, 1, "polId not 1");
    }

    function test_LicenseRegistry_addPolicy_revert_policyAlreadyAdded() public {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        vm.startPrank(address(module1));
        registry.addPolicy(policy);
        vm.expectRevert(Errors.LicenseRegistry__PolicyAlreadyAdded.selector);
        registry.addPolicy(policy);
        vm.stopPrank();
    }

    function test_LicenseRegistry_addPolicy_revert_frameworkNotFound() public {
        Licensing.Policy memory policy = _createPolicy();
        vm.expectRevert(Errors.LicenseRegistry__FrameworkNotFound.selector);
        vm.prank(address(module1));
        registry.addPolicy(policy);
    }

    function test_LicenseRegistry_addPolicyToIpId() public {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId = registry.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertFalse(registry.isPolicyInherited(ipId1, policyId));
        Licensing.Policy memory storedPolicy = registry.policy(policyId);
        assertEq(keccak256(abi.encode(storedPolicy)), keccak256(abi.encode(policy)), "policy not stored properly");
    }

    function test_LicenseRegistry_addSamePolicyReusesPolicyId() public {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);

        vm.prank(ipOwner);
        uint256 indexOnIpId = registry.addPolicyToIp(ipId1, policyId);
        assertEq(indexOnIpId, 0);
        assertFalse(registry.isPolicyInherited(ipId1, policyId));

        vm.prank(ipOwner);
        uint256 indexOnIpId2 = registry.addPolicyToIp(ipId2, policyId);
        assertEq(indexOnIpId2, 0);
        assertFalse(registry.isPolicyInherited(ipId2, policyId));
    }

    //function test_LicenseRegistry_revert_policyAlreadyAddedToIpId()

    function test_LicenseRegistry_add2PoliciesToIpId() public {
        module1.register();
        assertEq(registry.totalPolicies(), 0);
        assertEq(registry.totalPoliciesForIp(ipId1), 0);
        Licensing.Policy memory policy = _createPolicy();

        // First time adding a policy
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId = registry.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertEq(registry.totalPolicies(), 1, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(ipId1), 1, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(ipId1, 0), 1, "policyIdForIpAtIndex not 1");
        assertFalse(registry.isPolicyInherited(ipId1, policyId));

        // Adding different policy to same ipId
        policy.data = abi.encode(
            MockPolicy({
                returnVerifyLink: true,
                returnVerifyMint: true,
                returnVerifyTransfer: false
            })
        );
        vm.prank(address(module1));
        uint256 policyId2 = registry.addPolicy(policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId2 = registry.addPolicyToIp(ipId1, policyId2);
        assertEq(policyId2, 2, "policyId not 2");
        assertEq(indexOnIpId2, 1, "indexOnIpId not 1");
        assertEq(registry.totalPolicies(), 2, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(ipId1), 2, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(ipId1, 1), 2, "policyIdForIpAtIndex not 2");
        assertFalse(registry.isPolicyInherited(ipId1, policyId2));
    }

    function test_LicenseRegistry_mintLicense() public returns (uint256 licenseId) {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId = registry.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1);
        assertTrue(registry.isPolicyIdSetForIp(ipId1, policyId));

        uint256[] memory policyIds = registry.policyIdsForIp(ipId1);
        assertEq(policyIds.length, 1);
        assertEq(policyIds[indexOnIpId], policyId);

        licenseId = registry.mintLicense(policyId, ipId1, 2, licenseHolder);
        assertEq(licenseId, 1);
        Licensing.License memory license = registry.license(licenseId);
        assertEq(registry.balanceOf(licenseHolder, licenseId), 2);
        assertEq(registry.isLicensee(licenseId, licenseHolder), true);
        assertEq(license.policyId, policyId);
        assertEq(license.licensorIpId, ipId1);
        return licenseId;
    }

    function test_LicenseRegistry_mintLicense_revert_licensorNotRegistered() public {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);

        vm.expectRevert(Errors.LicenseRegistry__LicensorNotRegistered.selector);
        registry.mintLicense(policyId, address(0), 2, licenseHolder);
    }

    function test_LicenseRegistry_mintLicense_revert_callerNotLicensorAndIpIdHasNoPolicy() public {
        module1.register();   
        Licensing.Policy memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);     
        vm.expectRevert(Errors.LicenseRegistry__CallerNotLicensorAndPolicyNotSet.selector);
        registry.mintLicense(policyId, ipId1, 2, licenseHolder);
    }

    function test_LicenseRegistry_mintLicense_ipIdHasNoPolicyButCallerIsLicensor() public {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        IPAccountImpl ipAccount = IPAccountImpl(payable(ipId1));
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);
        address owner = ipAccount.owner();
        // Call with owner
        vm.prank(owner);
        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertEq(licenseId, 1);

        // Call with permission
        
        address signer = address(0x999);
        bytes4 selector = registry.mintLicense.selector;
        vm.prank(owner);
        ipAccount.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount),
                signer,
                address(registry),
                selector,
                AccessPermission.ALLOW
            )
        );
        vm.prank(signer);
        licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertEq(licenseId, 2);

        // Call from IP Account
        vm.prank(ipId1);
        licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);
        assertEq(licenseId, 3);
        // Call from IP Account from execute
        vm.prank(owner);
        bytes memory result = ipAccount.execute(
            address(registry),
            0,
            abi.encodeWithSignature(
                "mintLicense(uint256,address,uint256,address)",
                policyId,
                ipId1,
                1,
                licenseHolder
            )
        );
        assertEq(4, abi.decode(result, (uint256)));

    }



    function test_LicenseRegistry_linkIpToParent() public {
        uint256 licenseId = test_LicenseRegistry_mintLicense();
        vm.prank(ipOwner);
        registry.linkIpToParent(licenseId, ipId2, licenseHolder);
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
        assertEq(registry.isParent(ipId1, ipId2), true, "not parent");
        assertEq(
            keccak256(abi.encode(registry.policyForIpAtIndex(ipId2, 0))),
            keccak256(abi.encode(registry.policyForIpAtIndex(ipId1, 0))),
            "policy not copied"
        );
        assertEq(registry.policyIdForIpAtIndex(ipId2, 0), 1);
        assertTrue(registry.isPolicyInherited(ipId2, 1));

        address[] memory parents = registry.parentIpIds(ipId2);
        assertEq(parents.length, 1, "not 1 parent");
        assertEq(
            parents.length,
            registry.totalParentsForIpId(ipId2),
            "parents.length and totalParentsForIpId mismatch"
        );
        assertEq(parents[0], ipId1, "parent not ipId1");
    }

    function test_LicenseRegistry_singleTransfer_paramVerifyTrue() public {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = registry.mintLicense(policyId, ipId1, 2, licenseHolder);
        address licenseHolder2 = address(0x102);
        vm.prank(licenseHolder);
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
    }

    function test_LicenseRegistry_singleTransfer_verifyOk() public {
        module1.register();
        Licensing.Policy memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = registry.mintLicense(policyId, ipId1, 2, licenseHolder);

        address licenseHolder2 = address(0x102);
        assertEq(registry.balanceOf(licenseHolder, licenseId), 2);
        assertEq(registry.balanceOf(licenseHolder2, licenseId), 0);
        vm.prank(licenseHolder);
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
        assertEq(registry.balanceOf(licenseHolder2, licenseId), 1, "not minted");
    }

    function test_LicenseRegistry_singleTransfer_revert_verifyFalse() public {
        module1.register();
        Licensing.Policy memory policy = Licensing.Policy({
            policyFrameworkId: 1,
            data: abi.encode(
                MockPolicy({
                    returnVerifyLink: true,
                    returnVerifyMint: true,
                    returnVerifyTransfer: false
                })
            )
        });
        vm.prank(address(module1));
        uint256 policyId = registry.addPolicy(policy);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = registry.mintLicense(policyId, ipId1, 2, licenseHolder);

        address licenseHolder2 = address(0x102);
        vm.expectRevert(Errors.LicenseRegistry__TransferParamFailed.selector);
        vm.prank(licenseHolder);
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
    }

    function test_LicenseRegistry_licenseUri() public {
        umlManager.register();

        UMLPolicy memory policyData = UMLPolicy({
            attribution: true,
            transferable: true,
            commercialUse: true,
            commercialAttribution: true,
            commercializers: new string[](2),
            commercialRevShare: 0,
            derivativesAllowed: true,
            derivativesAttribution: true,
            derivativesApproval: true,
            derivativesReciprocal: true,
            derivativesRevShare: 0,
            territories: new string[](1),
            distributionChannels: new string[](1)
        });

        policyData.commercializers[0] = "commercializer1";
        policyData.commercializers[1] = "commercializer2";
        policyData.territories[0] = "territory1";
        policyData.distributionChannels[0] = "distributionChannel1";

        uint256 policyId = umlManager.addPolicy(policyData);

        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = registry.mintLicense(policyId, ipId1, 1, licenseHolder);

        string memory actualUri = registry.uri(licenseId);

        /* solhint-disable */
        // NOTE: In STRING version, no spacing between key and value (eg. "value":"true" instead of "value": "true")
        // DEV : Since the raw string below produces stack too deep error, we use the encoded output of the string below.
        //       The string below is left here for reference.
        /*
        string memory expectedJson = string(abi.encodePacked('{',
            '"name":"Story Protocol License NFT",'
            '"description":"License agreement stating the terms of a Story Protocol IPAsset",',
            '"attributes":[',
            '{',
                '"trait_type":"Attribution",'
                '"value":"true"',
            '},',
            '{',
                '"trait_type":"Transferable",',
                '"value":"true"',
            '},',
            '{',
                '"trait_type":"Commerical Use",',
                '"value":"true"',
            '},',
            '{',
                '"trait_type":"commercialAttribution",',
                '"value":"true"',
            '},',
            '{',
                '"trait_type":"commercialRevShare",',
                '"value":0',
            '},',
            '{',
                '"trait_type":"commercializers",',
                '"value":[',
                    '"commercializer1",',
                    '"commercializer2"',
                ']',
            '},',
            '{',
                '"trait_type":"derivativesAllowed",',
                '"value":"true"',
            '},',
            '{',
                '"trait_type":"derivativesAttribution",',
                '"value":"true"',
            '},',
            '{',
                '"trait_type":"derivativesApproval",',
                '"value":"true"',
            '},',
            '{',
                '"trait_type":"derivativesReciprocal",',
                '"value":"true"',
            '},',
            '{',
                '"trait_type":"derivativesRevShare",',
                '"value":0',
            '},',
            '{',
                '"trait_type":"territories",',
                '"value":[',
                    '"territory1",',
                ']',
            '},'
            '{',
                '"trait_type":"distributionChannels"',
                '"value":[',
                    '"distributionChannel1",',
                ']',
            '}',
            ']',
        '}'
        ));
        */
        /* solhint-enable */
        string memory expectedJson = "eyJuYW1lIjogIlN0b3J5IFByb3RvY29sIExpY2Vuc2UgTkZUIiwgImRlc2NyaXB0aW9uIjogIkxpY2Vuc2UgYWdyZWVtZW50IHN0YXRpbmcgdGhlIHRlcm1zIG9mIGEgU3RvcnkgUHJvdG9jb2wgSVBBc3NldCIsICJhdHRyaWJ1dGVzIjogW3sidHJhaXRfdHlwZSI6ICJBdHRyaWJ1dGlvbiIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIlRyYW5zZmVyYWJsZSIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIkNvbW1lcmljYWwgVXNlIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiY29tbWVyY2lhbEF0dHJpYnV0aW9uIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiY29tbWVyY2lhbFJldlNoYXJlIiwgInZhbHVlIjogMH0seyJ0cmFpdF90eXBlIjogImNvbW1lcmNpYWxpemVycyIsICJ2YWx1ZSI6IFsiY29tbWVyY2lhbGl6ZXIxIiwiY29tbWVyY2lhbGl6ZXIyIl19LCB7InRyYWl0X3R5cGUiOiAiZGVyaXZhdGl2ZXNBbGxvd2VkIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiZGVyaXZhdGl2ZXNBdHRyaWJ1dGlvbiIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogImRlcml2YXRpdmVzQXBwcm92YWwiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJkZXJpdmF0aXZlc1JlY2lwcm9jYWwiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJkZXJpdmF0aXZlc1JldlNoYXJlIiwgInZhbHVlIjogMH0seyJ0cmFpdF90eXBlIjogInRlcnJpdG9yaWVzIiwgInZhbHVlIjogWyJ0ZXJyaXRvcnkxIl19LCB7InRyYWl0X3R5cGUiOiAiZGlzdHJpYnV0aW9uQ2hhbm5lbHMiLCAidmFsdWUiOiBbImRpc3RyaWJ1dGlvbkNoYW5uZWwxIl19XX0=";

        string memory expectedUri = string(abi.encodePacked("data:application/json;base64,", expectedJson));

        assertEq(actualUri, expectedUri);
    }
}