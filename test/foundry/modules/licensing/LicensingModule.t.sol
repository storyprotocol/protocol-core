// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { RegisterUMLPolicyParams } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { MockTokenGatedHook } from "test/foundry/mocks/MockTokenGatedHook.sol";

// test
// solhint-disable-next-line max-line-length
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig, MockPolicy } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
import { MockAccessController } from "test/foundry/mocks/access/MockAccessController.sol";
import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract LicensingModuleTest is BaseTest {
    using Strings for *;

    MockAccessController internal mockAccessController = new MockAccessController();

    MockPolicyFrameworkManager internal mockPFM;
    UMLPolicyFrameworkManager internal umlManager;

    MockERC721 internal nft = new MockERC721("MockERC721");
    MockERC721 internal gatedNftFoo = new MockERC721{ salt: bytes32(uint256(1)) }("GatedNftFoo");
    MockERC721 internal gatedNftBar = new MockERC721{ salt: bytes32(uint256(2)) }("GatedNftBar");

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipOwner = address(0x100); // use static address, otherwise uri check fails because licensor changes
    address public licenseHolder = address(0x101);

    modifier withPolicyFrameworkManager() {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));
        _;
    }

    function setUp() public override {
        super.setUp();
        buildDeployModuleCondition(
            DeployModuleCondition({
                registrationModule: false,
                disputeModule: false,
                royaltyModule: false,
                taggingModule: false,
                licensingModule: true
            })
        );
        buildDeployPolicyCondition(DeployPolicyCondition({ arbitrationPolicySP: false, royaltyPolicyLAP: true }));
        buildDeployRegistryCondition(DeployRegistryCondition({ licenseRegistry: true, moduleRegistry: false }));
        deployConditionally();
        postDeploymentSetup();

        // TODO: Mock this
        mockRoyaltyPolicyLAP = royaltyPolicyLAP;

        // Setup Framework Managers (don't register PFM here, do in each test case)
        mockPFM = new MockPolicyFrameworkManager(
            MockPolicyFrameworkConfig({
                licensingModule: address(licensingModule),
                name: "MockPolicyFrameworkManager",
                licenseUrl: licenseUrl,
                royaltyPolicy: address(mockRoyaltyPolicyLAP)
            })
        );

        umlManager = new UMLPolicyFrameworkManager(
            address(mockAccessController),
            address(ipAccountRegistry),
            address(licensingModule),
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

        //        MockERC721 tempGatedNftFoo = new MockERC721("GatedNftFoo");
        //        bytes memory GatedNftFooCode = address(tempGatedNftFoo).code;
        //        address gatedNftFoo = makeAddr("GatedNftFoo");
        //        vm.etch(gatedNftFoo, GatedNftFooCode);
        //        deployCodeTo("test/foundry/mocks/MockTokenGatedHook.sol", gatedNftFoo);
    }

    function _createMockPolicy() internal pure returns (bytes memory) {
        return abi.encode(MockPolicy({ returnVerifyLink: true, returnVerifyMint: true }));
    }

    function _createPolicyFrameworkData() internal view returns (bytes memory) {
        return
            abi.encode(
                Licensing.Policy({
                    isLicenseTransferable: true,
                    policyFramework: address(mockPFM),
                    frameworkData: "",
                    royaltyPolicy: address(mockRoyaltyPolicyLAP),
                    royaltyData: ""
                })
            );
    }

    function test_LicensingModule_registerLicenseFramework() public {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));
        assertTrue(licensingModule.isFrameworkRegistered(address(mockPFM)), "framework not registered");
    }

    function test_LicensingModule_registerPolicy() public withPolicyFrameworkManager {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());
        assertEq(policyId, 1, "policyId not 1");
    }

    function test_LicensingModule_registerPolicy_reusesIdForAlreadyAddedPolicy() public withPolicyFrameworkManager {
        vm.startPrank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());
        assertEq(
            policyId,
            licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy())
        );
        vm.stopPrank();
    }

    function test_LicensingModule_getPolicyId() public withPolicyFrameworkManager {
        bytes memory policy = _createMockPolicy();
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());
        Licensing.Policy memory storedPolicy = licensingModule.policy(policyId);
        assertEq(licensingModule.getPolicyId(storedPolicy), policyId, "policyId not found");
    }

    function test_LicensingModule_registerPolicy_revert_frameworkNotFound() public {
        vm.expectRevert(Errors.LicensingModule__FrameworkNotFound.selector);
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());
    }

    function test_LicensingModule_addPolicyToIpId() public withPolicyFrameworkManager {
        bytes memory policyData = _createPolicyFrameworkData();

        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(
            true,
            address(mockRoyaltyPolicyLAP),
            "",
            _createPolicyFrameworkData()
        );

        vm.prank(ipOwner);
        uint256 indexOnIpId = licensingModule.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertFalse(licensingModule.isPolicyInherited(ipId1, policyId));

        Licensing.Policy memory storedPolicy = licensingModule.policy(policyId);
        assertEq(storedPolicy.policyFramework, address(mockPFM), "policyFramework not stored properly");
        assertEq(storedPolicy.royaltyPolicy, address(mockRoyaltyPolicyLAP), "royaltyPolicy not stored properly");
        assertEq(storedPolicy.isLicenseTransferable, true, "isLicenseTransferable not stored properly");
        assertEq(storedPolicy.frameworkData, policyData, "frameworkData not stored properly");
        assertEq(storedPolicy.royaltyData, "", "royaltyData not stored properly");
        // assertEq(keccak256(abi.encode(storedPolicy)), keccak256(abi.encode(policy)), "policy not stored properly");
    }

    function test_LicensingModule_addSamePolicyReusesPolicyId() public withPolicyFrameworkManager {
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());

        vm.prank(ipOwner);
        uint256 indexOnIpId = licensingModule.addPolicyToIp(ipId1, policyId);
        assertEq(indexOnIpId, 0);
        assertFalse(licensingModule.isPolicyInherited(ipId1, policyId));

        vm.prank(ipOwner);
        uint256 indexOnIpId2 = licensingModule.addPolicyToIp(ipId2, policyId);
        assertEq(indexOnIpId2, 0);
        assertFalse(licensingModule.isPolicyInherited(ipId2, policyId));
    }

    function test_LicensingModule_add2PoliciesToIpId() public withPolicyFrameworkManager {
        assertEq(licensingModule.totalPolicies(), 0);
        assertEq(licensingModule.totalPoliciesForIp(false, ipId1), 0);

        // First time adding a policy
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());
        vm.prank(ipOwner);
        uint256 indexOnIpId = licensingModule.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertEq(licensingModule.totalPolicies(), 1, "totalPolicies not incremented");
        assertEq(licensingModule.totalPoliciesForIp(false, ipId1), 1, "totalPoliciesForIp not incremented");
        assertEq(licensingModule.policyIdForIpAtIndex(false, ipId1, 0), 1, "policyIdForIpAtIndex not 1");
        (uint256 index, bool isInherited, bool active) = licensingModule.policyStatus(ipId1, policyId);
        assertFalse(isInherited);

        // Adding different policy to same ipId
        bytes memory otherPolicy = abi.encode(MockPolicy({ returnVerifyLink: true, returnVerifyMint: false }));
        vm.prank(address(mockPFM));
        uint256 policyId2 = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", otherPolicy);
        vm.prank(ipOwner);
        uint256 indexOnIpId2 = licensingModule.addPolicyToIp(ipId1, policyId2);
        assertEq(policyId2, 2, "policyId not 2");
        assertEq(indexOnIpId2, 1, "indexOnIpId not 1");
        assertEq(licensingModule.totalPolicies(), 2, "totalPolicies not incremented");
        assertEq(licensingModule.totalPoliciesForIp(false, ipId1), 2, "totalPoliciesForIp not incremented");
        assertEq(licensingModule.policyIdForIpAtIndex(false, ipId1, 1), 2, "policyIdForIpAtIndex not 2");
        (index, isInherited, active) = licensingModule.policyStatus(ipId1, policyId2);
        assertFalse(isInherited);
    }

    function test_LicensingModule_mintLicense() public withPolicyFrameworkManager returns (uint256 licenseId) {
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());
        vm.prank(ipOwner);
        uint256 indexOnIpId = licensingModule.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1);

        assertTrue(licensingModule.isPolicyIdSetForIp(false, ipId1, policyId));
        uint256[] memory policyIds = licensingModule.policyIdsForIp(false, ipId1);
        assertEq(policyIds.length, 1);
        assertEq(policyIds[indexOnIpId], policyId);

        licenseId = licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder, "");
        assertEq(licenseId, 1);
        Licensing.License memory license = licenseRegistry.license(licenseId);
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 2);
        assertEq(licenseRegistry.isLicensee(licenseId, licenseHolder), true);
        assertEq(license.policyId, policyId);
        assertEq(license.licensorIpId, ipId1);
        return licenseId;
    }

    function test_LicensingModule_mintLicense_revert_licensorNotRegistered() public {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));

        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        vm.expectRevert(Errors.LicensingModule__LicensorNotRegistered.selector);
        licensingModule.mintLicense(policyId, address(0), 2, licenseHolder, "");
    }

    function test_LicensingModule_mintLicense_revert_callerNotLicensorAndIpIdHasNoPolicy() public {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));

        IPAccountImpl ipAccount1 = IPAccountImpl(payable(ipId1));

        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());

        // Anyone (this contract, in this case) calls
        vm.expectRevert(Errors.LicensingModule__CallerNotLicensorAndPolicyNotSet.selector);
        licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder, "");

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
                address(licensingModule),
                licensingModule.mintLicense.selector,
                AccessPermission.ALLOW
            )
        );

        vm.expectRevert(Errors.LicensingModule__CallerNotLicensorAndPolicyNotSet.selector);
        vm.prank(signer);
        licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder, "");
    }

    function test_LicensingModule_mintLicense_ipIdHasNoPolicyButCallerIsLicensor() public {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));

        bytes memory policy = _createMockPolicy();
        IPAccountImpl ipAccount1 = IPAccountImpl(payable(ipId1));

        vm.startPrank(address(mockPFM));
        uint256 policyId1 = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", policy);
        uint256 policyId2 = licensingModule.registerPolicy(false, address(mockRoyaltyPolicyLAP), "", policy);
        vm.stopPrank();

        // Licensor (IP Account owner) calls directly
        vm.prank(ipAccount1.owner());
        uint256 licenseId = licensingModule.mintLicense(policyId1, ipId1, 1, licenseHolder, "");
        assertEq(licenseId, 1);

        // Licensor (IP Account owner) calls via IP Account execute
        // The returned license ID (from decoding `result`) should be the same as above, as we're not creating a new
        // license, but rather minting an existing one (existing ID, minted above).
        vm.prank(ipAccount1.owner());
        bytes memory result = ipAccount1.execute(
            address(licensingModule),
            0,
            abi.encodeWithSignature(
                "mintLicense(uint256,address,uint256,address,bytes)",
                policyId1,
                ipId1,
                1,
                licenseHolder,
                ""
            )
        );
        assertEq(1, abi.decode(result, (uint256)));

        // IP Account calls directly
        vm.prank(ipId1);
        licenseId = licensingModule.mintLicense(policyId2, ipId1, 1, licenseHolder, "");
        assertEq(licenseId, 2); // new license ID as this is the first mint on a different policy
    }

    function test_LicensingModule_linkIpToParents_single_parent() public {
        uint256 licenseId = test_LicensingModule_mintLicense();
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, ipOwner, licenseId, 2, "");

        vm.prank(ipOwner);
        licensingModule.linkIpToParents(licenseIds, ipId2, "");

        assertEq(licenseRegistry.balanceOf(ipOwner, licenseId), 1, "not burnt");
        assertEq(licensingModule.isParent(ipId1, ipId2), true, "not parent");
        assertEq(
            keccak256(abi.encode(licensingModule.policyForIpAtIndex(true, ipId2, 0))),
            keccak256(abi.encode(licensingModule.policyForIpAtIndex(false, ipId1, 0))),
            "policy not copied"
        );
        assertEq(licensingModule.policyIdForIpAtIndex(true, ipId2, 0), 1);
        (uint256 index, bool isInherited, bool active) = licensingModule.policyStatus(ipId2, 1);
        assertEq(index, 0, "index not 0");
        assertEq(isInherited, true, "not inherited");
        assertEq(active, true, "not active");

        address[] memory parents = licensingModule.parentIpIds(ipId2);
        assertEq(parents.length, 1, "not 1 parent");
        assertEq(
            parents.length,
            licensingModule.totalParentsForIpId(ipId2),
            "parents.length and totalParentsForIpId mismatch"
        );
        assertEq(parents[0], ipId1, "parent not ipId1");
    }

    function test_LicensingModule_singleTransfer_verifyOk() public {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(true, address(mockRoyaltyPolicyLAP), "", _createMockPolicy());

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder, "");

        address licenseHolder2 = address(0x102);
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 2);
        assertEq(licenseRegistry.balanceOf(licenseHolder2, licenseId), 0);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
        assertEq(licenseRegistry.balanceOf(licenseHolder2, licenseId), 1, "not minted");
    }

    function test_LicensingModule_singleTransfer_revert_verifyFalse() public {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(
            false,
            address(mockRoyaltyPolicyLAP),
            "",
            _createMockPolicy()
        );

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder, "");

        address licenseHolder2 = address(0x102);
        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
    }

    function test_LicensingModule_licenseUri() public {
        licensingModule.registerPolicyFrameworkManager(address(umlManager));

        _mapUMLPolicySimple({
            name: "pol_a",
            commercial: true,
            derivatives: true,
            reciprocal: false,
            commercialRevShare: 100
        });
        RegisterUMLPolicyParams memory inputA = _getMappedUmlParams("pol_a");

        gatedNftFoo.mintId(address(this), 1);

        MockTokenGatedHook tokenGatedHook = new MockTokenGatedHook();
        inputA.policy.commercializerChecker = address(tokenGatedHook);
        inputA.policy.commercializerCheckerData = abi.encode(address(gatedNftFoo));
        inputA.policy.territories = new string[](1);
        inputA.policy.territories[0] = "territory1";
        inputA.policy.distributionChannels = new string[](1);
        inputA.policy.distributionChannels[0] = "distributionChannel1";

        uint256 policyId = umlManager.registerPolicy(inputA);

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        // Set the licensor to `0xbeef` for uri testing. Must call LicenseRegistry directly to do so.
        vm.prank(address(licensingModule));
        uint256 licenseId = licensingModule.mintLicense(policyId, address(0xbeef), 1, licenseHolder, "");

        string memory actualUri = LicenseRegistry(address(licenseRegistry)).uri(licenseId);

        /* solhint-disable */
        // NOTE: In STRING version, no spacing between key and value (eg. "value":"true" instead of "value": "true")
        // DEV : Since the raw string below produces stack too deep error, we use the encoded output of the string below.
        //       The string below is left here for reference.
        /*
        expectedJson = {
            "name": "Story Protocol License NFT",
            "description": "License agreement stating the terms of a Story Protocol IPAsset",
            "external_url": "https://protocol.storyprotocol.xyz/ipa/0x000000000000000000000000000000000000beef",
            "image": "https://images.ctfassets.net/5ei3wx54t1dp/1WXOHnPLROsGiBsI46zECe/4f38a95c58d3b0329af3085b36d720c8/Story_Protocol_Icon.png",
            "attributes": [
                {
                    "trait_type": "Attribution",
                    "value": "true"
                },
                {
                    "trait_type": "Transferable",
                    "value": "true"
                },
                {
                    "trait_type": "Attribution",
                    "value": "true"
                },
                {
                    "trait_type": "Commerical Use",
                    "value": "true"
                },
                {
                    "trait_type": "Commercial Attribution",
                    "value": "true"
                },
                {
                    "trait_type": "Commercial Revenue Share",
                    "max_value": 1000,
                    "value": 0
                },
                {
                    "trait_type": "Commercializer Check",
                    "value": "0x210503c318855259983298ba58055a38d5ff63e0"
                },
                {
                    "trait_type": "Derivatives Allowed",
                    "value": "true"
                },
                {
                    "trait_type": "Derivatives Attribution",
                    "value": "true"
                },
                {
                    "trait_type": "Derivatives Approval",
                    "value": "true"
                },
                {
                    "trait_type": "Derivatives Reciprocal",
                    "value": "true"
                },
                {
                    "trait_type": "Derivatives Revenue Share",
                    "max_value": 1000,
                    "value": 0
                },
                {
                    "trait_type": "Territories",
                    "value": [
                        "territory1"
                    ]
                },
                {
                    "trait_type": "Distribution Channels",
                    "value": [
                        "distributionChannel1"
                    ]
                },
                {
                    "trait_type": "Licensor",
                    "value": "0x000000000000000000000000000000000000beef"
                },
                {
                    "trait_type": "Policy Framework",
                    "value": "0xf1e1d77c54e9c28cc1da2dbc377b4a85765c2542"
                },
                {
                    "trait_type": "Transferable",
                    "value": "true"
                },
                {
                    "trait_type": "Revoked",
                    "value": "false"
                }
            ]
        };
        */
        /* solhint-enable */

        /* solhint-disable */
        string
            memory expectedJson = "eyJuYW1lIjogIlN0b3J5IFByb3RvY29sIExpY2Vuc2UgTkZUIiwiZGVzY3JpcHRpb24iOiAiTGljZW5zZSBhZ3JlZW1lbnQgc3RhdGluZyB0aGUgdGVybXMgb2YgYSBTdG9yeSBQcm90b2NvbCBJUEFzc2V0IiwiZXh0ZXJuYWxfdXJsIjogImh0dHBzOi8vcHJvdG9jb2wuc3Rvcnlwcm90b2NvbC54eXovaXBhLzB4MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwYmVlZiIsImltYWdlIjogImh0dHBzOi8vaW1hZ2VzLmN0ZmFzc2V0cy5uZXQvNWVpM3d4NTR0MWRwLzFXWE9IblBMUk9zR2lCc0k0NnpFQ2UvNGYzOGE5NWM1OGQzYjAzMjlhZjMwODViMzZkNzIwYzgvU3RvcnlfUHJvdG9jb2xfSWNvbi5wbmciLCJhdHRyaWJ1dGVzIjogW3sidHJhaXRfdHlwZSI6ICJBdHRyaWJ1dGlvbiIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIlRyYW5zZmVyYWJsZSIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIkF0dHJpYnV0aW9uIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiQ29tbWVyaWNhbCBVc2UiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJDb21tZXJjaWFsIEF0dHJpYnV0aW9uIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiQ29tbWVyY2lhbCBSZXZlbnVlIFNoYXJlIiwgIm1heF92YWx1ZSI6IDEwMDAsICJ2YWx1ZSI6IDB9LHsidHJhaXRfdHlwZSI6ICJDb21tZXJjaWFsaXplciBDaGVjayIsICJ2YWx1ZSI6ICIweDIxMDUwM2MzMTg4NTUyNTk5ODMyOThiYTU4MDU1YTM4ZDVmZjYzZTAifSx7InRyYWl0X3R5cGUiOiAiRGVyaXZhdGl2ZXMgQWxsb3dlZCIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIkRlcml2YXRpdmVzIEF0dHJpYnV0aW9uIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiRGVyaXZhdGl2ZXMgQXBwcm92YWwiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJEZXJpdmF0aXZlcyBSZWNpcHJvY2FsIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiRGVyaXZhdGl2ZXMgUmV2ZW51ZSBTaGFyZSIsICJtYXhfdmFsdWUiOiAxMDAwLCAidmFsdWUiOiAwfSx7InRyYWl0X3R5cGUiOiAiVGVycml0b3JpZXMiLCAidmFsdWUiOiBbInRlcnJpdG9yeTEiXX0seyJ0cmFpdF90eXBlIjogIkRpc3RyaWJ1dGlvbiBDaGFubmVscyIsICJ2YWx1ZSI6IFsiZGlzdHJpYnV0aW9uQ2hhbm5lbDEiXX0seyJ0cmFpdF90eXBlIjogIkxpY2Vuc29yIiwgInZhbHVlIjogIjB4MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwYmVlZiJ9LHsidHJhaXRfdHlwZSI6ICJQb2xpY3kgRnJhbWV3b3JrIiwgInZhbHVlIjogIjB4ZjFlMWQ3N2M1NGU5YzI4Y2MxZGEyZGJjMzc3YjRhODU3NjVjMjU0MiJ9LHsidHJhaXRfdHlwZSI6ICJUcmFuc2ZlcmFibGUiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJSZXZva2VkIiwgInZhbHVlIjogImZhbHNlIn1dfQ==";
        /* solhint-enable */

        string memory expectedUri = string(abi.encodePacked("data:application/json;base64,", expectedJson));

        assertEq(actualUri, expectedUri);
    }

    function test_LicensingModule_revert_HookVerifyFail() public {
        licensingModule.registerPolicyFrameworkManager(address(umlManager));

        UMLPolicy memory policyData = UMLPolicy({
            attribution: true,
            commercialUse: true,
            commercialAttribution: false,
            commercializerChecker: address(0),
            commercializerCheckerData: "",
            commercialRevShare: 100,
            derivativesAllowed: false,
            derivativesAttribution: false,
            derivativesApproval: false,
            derivativesReciprocal: false,
            territories: new string[](1),
            distributionChannels: new string[](1),
            contentRestrictions: emptyStringArray
        });

        gatedNftFoo.mintId(address(this), 1);

        MockTokenGatedHook tokenGatedHook = new MockTokenGatedHook();
        policyData.commercializerChecker = address(tokenGatedHook);
        // address(this) doesn't hold token of NFT collection gatedNftBar, so the verification will fail
        policyData.commercializerCheckerData = abi.encode(address(gatedNftBar));
        policyData.territories[0] = "territory1";
        policyData.distributionChannels[0] = "distributionChannel1";

        uint256 policyId = umlManager.registerPolicy(
            RegisterUMLPolicyParams({
                transferable: true,
                // TODO: use mock or real based on condition
                royaltyPolicy: address(mockRoyaltyPolicyLAP),
                policy: policyData
            })
        );

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        vm.expectRevert(Errors.LicensingModule__MintLicenseParamFailed.selector);
        licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder, "");
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
