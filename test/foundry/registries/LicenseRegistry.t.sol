// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// external
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test } from "forge-std/Test.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";

// contracts
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

// test
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig, MockPolicy } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

contract LicenseRegistryTest is Test {
    using Strings for *;
    using ShortStrings for *;

    MockAccessController internal accessController = new MockAccessController();
    IPAccountRegistry internal ipAccountRegistry;

    LicenseRegistry internal registry;

    MockPolicyFrameworkManager internal module1;
    UMLPolicyFrameworkManager internal umlManager;

    MockERC721 internal nft = new MockERC721("MockERC721");

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipOwner = vm.addr(1);
    address public licenseHolder = address(0x101);

    function setUp() public {
        // Registry
        ipAccountRegistry = new IPAccountRegistry(
            address(new ERC6551Registry()),
            address(accessController),
            address(new IPAccountImpl())
        );
        registry = new LicenseRegistry(address(accessController), address(ipAccountRegistry));

        // Setup Framework Managers (don't register PFM here, do in each test case)
        module1 = new MockPolicyFrameworkManager(
            MockPolicyFrameworkConfig({
                licenseRegistry: address(registry),
                name: "MockPolicyFrameworkManager",
                licenseUrl: licenseUrl,
                supportVerifyLink: true,
                supportVerifyMint: true,
                supportVerifyTransfer: true
            })
        );
        umlManager = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(registry),
            address(0), // TODO: mock royaltyModule
            "UMLPolicyFrameworkManager",
            licenseUrl
        );

        // Create IPAccounts
        nft.mintId(ipOwner, 1);
        nft.mintId(ipOwner, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);

        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
    }

    function _createPolicy() internal pure returns (bytes memory) {
        return abi.encode(MockPolicy({ returnVerifyLink: true, returnVerifyMint: true, returnVerifyTransfer: true }));
    }

    function test_LicenseRegistry_registerLicenseFramework() public {
        registry.registerPolicyFrameworkManager(address(module1));
        assertTrue(registry.isFrameworkRegistered(address(module1)), "framework not registered");
    }

    function test_LicenseRegistry_registerPolicy() public {
        registry.registerPolicyFrameworkManager(address(module1));
        vm.prank(address(module1));
        uint256 polId = registry.registerPolicy(_createPolicy());
        assertEq(polId, 1, "polId not 1");
    }

    function test_LicenseRegistry_registerPolicy_revert_policyAlreadyAdded() public {
        registry.registerPolicyFrameworkManager(address(module1));
        vm.startPrank(address(module1));
        registry.registerPolicy(_createPolicy());
        vm.expectRevert(Errors.LicenseRegistry__PolicyAlreadyAdded.selector);
        registry.registerPolicy(_createPolicy());
        vm.stopPrank();
    }

    function test_LicenseRegistry_registerPolicy_revert_frameworkNotFound() public {
        bytes memory policy = _createPolicy();
        vm.expectRevert(Errors.LicenseRegistry__FrameworkNotFound.selector);
        vm.prank(address(module1));
        registry.registerPolicy(policy);
    }

    function test_LicenseRegistry_addPolicyToIpId() public {
        registry.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId = registry.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertFalse(registry.isPolicyInherited(ipId1, policyId));
        Licensing.Policy memory storedPolicy = registry.policy(policyId);
        assertEq(storedPolicy.policyFramework, address(module1), "policyFramework not stored properly");
        assertEq(keccak256(storedPolicy.data), keccak256(policy), "policy not stored properly");
    }

    function test_LicenseRegistry_addSamePolicyReusesPolicyId() public {
        registry.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);

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
        registry.registerPolicyFrameworkManager(address(module1));
        assertEq(registry.totalPolicies(), 0);
        assertEq(registry.totalPoliciesForIp(false, ipId1), 0);
        bytes memory policy = _createPolicy();

        // First time adding a policy
        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId = registry.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertEq(registry.totalPolicies(), 1, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(false, ipId1), 1, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(false, ipId1, 0), 1, "policyIdForIpAtIndex not 1");
        (uint256 index, bool isInherited, bool active) = registry.policyStatus(ipId1, policyId);
        assertFalse(isInherited);

        // Adding different policy to same ipId
        policy = abi.encode(
            MockPolicy({ returnVerifyLink: true, returnVerifyMint: true, returnVerifyTransfer: false })
        );
        vm.prank(address(module1));
        uint256 policyId2 = registry.registerPolicy(policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId2 = registry.addPolicyToIp(ipId1, policyId2);
        assertEq(policyId2, 2, "policyId not 2");
        assertEq(indexOnIpId2, 1, "indexOnIpId not 1");
        assertEq(registry.totalPolicies(), 2, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(false, ipId1), 2, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(false, ipId1, 1), 2, "policyIdForIpAtIndex not 2");
        (index, isInherited, active) = registry.policyStatus(ipId1, policyId2);
        assertFalse(isInherited);
    }

    function test_LicenseRegistry_mintLicense() public returns (uint256 licenseId) {
        registry.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId = registry.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1);

        assertTrue(registry.isPolicyIdSetForIp(false, ipId1, policyId));
        uint256[] memory policyIds = registry.policyIdsForIp(false, ipId1);
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
        registry.registerPolicyFrameworkManager(address(module1));

        bytes memory policy = _createPolicy();

        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);

        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);

        vm.expectRevert(Errors.LicenseRegistry__LicensorNotRegistered.selector);
        registry.mintLicense(policyId, address(0), 2, licenseHolder);
    }

    function test_LicenseRegistry_mintLicense_revert_callerNotLicensorAndIpIdHasNoPolicy() public {
        registry.registerPolicyFrameworkManager(address(module1));

        bytes memory policy = _createPolicy();
        IPAccountImpl ipAccount1 = IPAccountImpl(payable(ipId1));

        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);

        // Anyone (this contract, in this case) calls
        vm.expectRevert(Errors.LicenseRegistry__CallerNotLicensorAndPolicyNotSet.selector);
        registry.mintLicense(policyId, ipId1, 2, licenseHolder);

        // Anyone, but call with permission (still fails)
        address signer = address(0x999);

        vm.prank(ipAccount1.owner());
        ipAccount1.execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                address(ipAccount1),
                signer,
                address(registry),
                registry.mintLicense.selector,
                AccessPermission.ALLOW
            )
        );

        vm.expectRevert(Errors.LicenseRegistry__CallerNotLicensorAndPolicyNotSet.selector);
        vm.prank(signer);
        registry.mintLicense(policyId, ipId1, 1, licenseHolder);
    }

    function test_LicenseRegistry_mintLicense_ipIdHasNoPolicyButCallerIsLicensor() public {
        registry.registerPolicyFrameworkManager(address(module1));

        bytes memory policy = _createPolicy();
        bytes memory policy2 = abi.encode(
            MockPolicy({ returnVerifyLink: true, returnVerifyMint: true, returnVerifyTransfer: false })
        );
        IPAccountImpl ipAccount1 = IPAccountImpl(payable(ipId1));

        vm.startPrank(address(module1));
        uint256 policyId1 = registry.registerPolicy(policy);
        uint256 policyId2 = registry.registerPolicy(policy2);
        vm.stopPrank();

        // Licensor (IP Account owner) calls directly
        vm.prank(ipAccount1.owner());
        uint256 licenseId = registry.mintLicense(policyId1, ipId1, 1, licenseHolder);
        assertEq(licenseId, 1);

        // Licensor (IP Account owner) calls via IP Account execute
        // The returned license ID (from decoding `result`) should be the same as above, as we're not creating a new
        // license, but rather minting an existing one (existing ID, minted above).
        vm.prank(ipAccount1.owner());
        bytes memory result = ipAccount1.execute(
            address(registry),
            0,
            abi.encodeWithSignature("mintLicense(uint256,address,uint256,address)", policyId1, ipId1, 1, licenseHolder)
        );
        assertEq(1, abi.decode(result, (uint256)));

        // IP Account calls directly
        vm.prank(ipId1);
        licenseId = registry.mintLicense(policyId2, ipId1, 1, licenseHolder);
        assertEq(licenseId, 2); // new license ID as this is the first mint on a different policy
    }

    function test_LicenseRegistry_linkIpToParents_single_parent() public {
        uint256 licenseId = test_LicenseRegistry_mintLicense();
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;
        vm.prank(ipOwner);
        registry.linkIpToParents(licenseIds, ipId2, licenseHolder);
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
        assertEq(registry.isParent(ipId1, ipId2), true, "not parent");
        assertEq(
            keccak256(abi.encode(registry.policyForIpAtIndex(true, ipId2, 0))),
            keccak256(abi.encode(registry.policyForIpAtIndex(false, ipId1, 0))),
            "policy not copied"
        );
        assertEq(registry.policyIdForIpAtIndex(true, ipId2, 0), 1);
        (uint256 index, bool isInherited, bool active) = registry.policyStatus(ipId2, 1);
        assertEq(index, 0, "index not 0");
        assertEq(isInherited, true, "not inherited");
        assertEq(active, true, "not active");

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
        registry.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = registry.mintLicense(policyId, ipId1, 2, licenseHolder);
        address licenseHolder2 = address(0x102);
        vm.prank(licenseHolder);
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
    }

    function test_LicenseRegistry_singleTransfer_verifyOk() public {
        registry.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);
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
        registry.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = abi.encode(
            MockPolicy({ returnVerifyLink: true, returnVerifyMint: true, returnVerifyTransfer: false })
        );
        vm.prank(address(module1));
        uint256 policyId = registry.registerPolicy(policy);
        vm.prank(ipOwner);
        registry.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = registry.mintLicense(policyId, ipId1, 2, licenseHolder);

        address licenseHolder2 = address(0x102);
        vm.expectRevert(Errors.LicenseRegistry__TransferParamFailed.selector);
        vm.prank(licenseHolder);
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
    }

    function test_LicenseRegistry_licenseUri() public {
        registry.registerPolicyFrameworkManager(address(umlManager));

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
            distributionChannels: new string[](1),
            royaltyPolicy: address(0xbeef) // TODO: mock royaltyPolicyLS
        });

        policyData.commercializers[0] = "commercializer1";
        policyData.commercializers[1] = "commercializer2";
        policyData.territories[0] = "territory1";
        policyData.distributionChannels[0] = "distributionChannel1";

        uint256 policyId = umlManager.registerPolicy(policyData);

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
        string
            memory expectedJson = "eyJuYW1lIjogIlN0b3J5IFByb3RvY29sIExpY2Vuc2UgTkZUIiwgImRlc2NyaXB0aW9uIjogIkxpY2Vuc2UgYWdyZWVtZW50IHN0YXRpbmcgdGhlIHRlcm1zIG9mIGEgU3RvcnkgUHJvdG9jb2wgSVBBc3NldCIsICJhdHRyaWJ1dGVzIjogW3sidHJhaXRfdHlwZSI6ICJBdHRyaWJ1dGlvbiIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIlRyYW5zZmVyYWJsZSIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIkNvbW1lcmljYWwgVXNlIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiY29tbWVyY2lhbEF0dHJpYnV0aW9uIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiY29tbWVyY2lhbFJldlNoYXJlIiwgInZhbHVlIjogMH0seyJ0cmFpdF90eXBlIjogImNvbW1lcmNpYWxpemVycyIsICJ2YWx1ZSI6IFsiY29tbWVyY2lhbGl6ZXIxIiwiY29tbWVyY2lhbGl6ZXIyIl19LCB7InRyYWl0X3R5cGUiOiAiZGVyaXZhdGl2ZXNBbGxvd2VkIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiZGVyaXZhdGl2ZXNBdHRyaWJ1dGlvbiIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogImRlcml2YXRpdmVzQXBwcm92YWwiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJkZXJpdmF0aXZlc1JlY2lwcm9jYWwiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJkZXJpdmF0aXZlc1JldlNoYXJlIiwgInZhbHVlIjogMH0seyJ0cmFpdF90eXBlIjogInRlcnJpdG9yaWVzIiwgInZhbHVlIjogWyJ0ZXJyaXRvcnkxIl19LCB7InRyYWl0X3R5cGUiOiAiZGlzdHJpYnV0aW9uQ2hhbm5lbHMiLCAidmFsdWUiOiBbImRpc3RyaWJ1dGlvbkNoYW5uZWwxIl19XX0=";

        string memory expectedUri = string(abi.encodePacked("data:application/json;base64,", expectedJson));

        assertEq(actualUri, expectedUri);
    }
}
