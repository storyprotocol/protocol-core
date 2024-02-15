// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test } from "forge-std/Test.sol";
import { ERC6551Registry } from "@erc6551/ERC6551Registry.sol";

// contracts
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";

// test
// solhint-disable-next-line max-line-length
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig, MockPolicy } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { MockRoyaltyPolicyLS } from "test/foundry/mocks/MockRoyaltyPolicyLS.sol";

contract LicensingModuleTest is Test {
    using Strings for *;

    MockAccessController internal accessController = new MockAccessController();
    IPAccountRegistry internal ipAccountRegistry;

    LicenseRegistry internal licenseRegistry;
    LicensingModule internal licensingModule;

    MockPolicyFrameworkManager internal module1;
    UMLPolicyFrameworkManager internal umlManager;

    MockERC721 internal nft = new MockERC721("MockERC721");

    ModuleRegistry internal moduleRegistry;

    ERC6551Registry internal erc6551Registry;

    IPAccountImpl internal ipAccountImpl;

    RoyaltyModule internal royaltyModule;

    IPAssetRegistry internal ipAssetRegistry;

    MockRoyaltyPolicyLS internal mockRoyaltyPolicyLS;

    string public licenseUrl = "https://example.com/license";
    address public ipId1;
    address public ipId2;
    address public ipOwner = vm.addr(1);
    address public licenseHolder = address(0x101);

    function setUp() public {
        // Registry
        Governance governance = new Governance(address(this));
        erc6551Registry = new ERC6551Registry();
        ipAccountImpl = new IPAccountImpl();
        ipAccountRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(ipAccountImpl)
        );
        moduleRegistry = new ModuleRegistry(address(governance));
        ipAssetRegistry = new IPAssetRegistry(
            address(accessController),
            address(erc6551Registry),
            address(ipAccountImpl),
            address(moduleRegistry),
            address(governance)
        );
        royaltyModule = new RoyaltyModule(address(accessController), address(ipAssetRegistry),address(governance));
        licenseRegistry = new LicenseRegistry();
        licensingModule = new LicensingModule(
            address(accessController),
            address(ipAssetRegistry),
            address(royaltyModule),
            address(licenseRegistry)
        );
        mockRoyaltyPolicyLS = new MockRoyaltyPolicyLS(address(royaltyModule));

        licenseRegistry.setLicensingModule(address(licensingModule));
        // Setup Framework Managers (don't register PFM here, do in each test case)
        module1 = new MockPolicyFrameworkManager(
            MockPolicyFrameworkConfig({
                licensingModule: address(licensingModule),
                name: "MockPolicyFrameworkManager",
                licenseUrl: licenseUrl,
                supportVerifyLink: true,
                supportVerifyMint: true,
                royaltyPolicy: address(mockRoyaltyPolicyLS)
            })
        );
        umlManager = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "UMLPolicyFrameworkManager",
            licenseUrl
        );
        IPResolver ipResolver = new IPResolver(address(accessController), address(ipAssetRegistry));
        RegistrationModule registrationModule = new RegistrationModule(
            address(accessController),
            address(ipAssetRegistry),
            address(licensingModule),
            address(ipResolver)
        );

        ipAssetRegistry.setRegistrationModule(address(registrationModule));
        // Set licensing module in royalty module
        royaltyModule.setLicensingModule(address(licensingModule));
        royaltyModule.whitelistRoyaltyPolicy(address(mockRoyaltyPolicyLS), true);

        // Create IPAccounts
        nft.mintId(ipOwner, 1);
        nft.mintId(ipOwner, 2);
        ipId1 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 1);
        ipId2 = ipAccountRegistry.registerIpAccount(block.chainid, address(nft), 2);

        vm.label(ipId1, "IPAccount1");
        vm.label(ipId2, "IPAccount2");
    }

    function _createPolicy() internal pure returns (bytes memory) {
        return abi.encode(MockPolicy({ returnVerifyLink: true, returnVerifyMint: true }));
    }

    function test_LicensingModule_registerLicenseFramework() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        assertTrue(licensingModule.isFrameworkRegistered(address(module1)), "framework not registered");
    }

    function test_LicensingModule_registerPolicy() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        vm.prank(address(module1));
        uint256 polId = licensingModule.registerPolicy(true, _createPolicy());
        assertEq(polId, 1, "polId not 1");
    }

    function test_LicensingModule_registerPolicy_reusesIdForAlreadyAddedPolicy() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        vm.startPrank(address(module1));
        uint256 polId = licensingModule.registerPolicy(true, _createPolicy());
        assertEq(polId, licensingModule.registerPolicy(true, _createPolicy()));
        vm.stopPrank();
    }

    function test_LicensingModule_getPolicyId() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);
        assertEq(licensingModule.getPolicyId(address(module1), true, policy), policyId, "policyId not found");
    }

    function test_LicensingModule_registerPolicy_revert_frameworkNotFound() public {
        bytes memory policy = _createPolicy();
        vm.expectRevert(Errors.LicensingModule__FrameworkNotFound.selector);
        vm.prank(address(module1));
        licensingModule.registerPolicy(true, policy);
    }

    function test_LicensingModule_addPolicyToIpId() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId = licensingModule.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertFalse(licensingModule.isPolicyInherited(ipId1, policyId));
        Licensing.Policy memory storedPolicy = licensingModule.policy(policyId);
        assertEq(storedPolicy.policyFramework, address(module1), "policyFramework not stored properly");
        assertEq(keccak256(storedPolicy.data), keccak256(policy), "policy not stored properly");
    }

    function test_LicensingModule_addSamePolicyReusesPolicyId() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);

        vm.prank(ipOwner);
        uint256 indexOnIpId = licensingModule.addPolicyToIp(ipId1, policyId);
        assertEq(indexOnIpId, 0);
        assertFalse(licensingModule.isPolicyInherited(ipId1, policyId));

        vm.prank(ipOwner);
        uint256 indexOnIpId2 = licensingModule.addPolicyToIp(ipId2, policyId);
        assertEq(indexOnIpId2, 0);
        assertFalse(licensingModule.isPolicyInherited(ipId2, policyId));
    }

    //function test_LicensingModule_revert_policyAlreadyAddedToIpId()

    function test_LicensingModule_add2PoliciesToIpId() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        assertEq(licensingModule.totalPolicies(), 0);
        assertEq(licensingModule.totalPoliciesForIp(false, ipId1), 0);
        bytes memory policy = _createPolicy();

        // First time adding a policy
        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);
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
        policy = abi.encode(MockPolicy({ returnVerifyLink: true, returnVerifyMint: false }));
        vm.prank(address(module1));
        uint256 policyId2 = licensingModule.registerPolicy(true, policy);
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

    function test_LicensingModule_mintLicense() public returns (uint256 licenseId) {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);
        vm.prank(ipOwner);
        uint256 indexOnIpId = licensingModule.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1);

        assertTrue(licensingModule.isPolicyIdSetForIp(false, ipId1, policyId));
        uint256[] memory policyIds = licensingModule.policyIdsForIp(false, ipId1);
        assertEq(policyIds.length, 1);
        assertEq(policyIds[indexOnIpId], policyId);

        licenseId = licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder);
        assertEq(licenseId, 1);
        Licensing.License memory license = licenseRegistry.license(licenseId);
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 2);
        assertEq(licenseRegistry.isLicensee(licenseId, licenseHolder), true);
        assertEq(license.policyId, policyId);
        assertEq(license.licensorIpId, ipId1);
        return licenseId;
    }

    function test_LicensingModule_mintLicense_revert_licensorNotRegistered() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));

        bytes memory policy = _createPolicy();

        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        vm.expectRevert(Errors.LicensingModule__LicensorNotRegistered.selector);
        licensingModule.mintLicense(policyId, address(0), 2, licenseHolder);
    }

    function test_LicensingModule_mintLicense_revert_callerNotLicensorAndIpIdHasNoPolicy() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));

        bytes memory policy = _createPolicy();
        IPAccountImpl ipAccount1 = IPAccountImpl(payable(ipId1));

        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);

        // Anyone (this contract, in this case) calls
        vm.expectRevert(Errors.LicensingModule__CallerNotLicensorAndPolicyNotSet.selector);
        licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder);

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
        licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder);
    }

    function test_LicensingModule_mintLicense_ipIdHasNoPolicyButCallerIsLicensor() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));

        bytes memory policy = _createPolicy();
        bytes memory policy2 = abi.encode(MockPolicy({ returnVerifyLink: true, returnVerifyMint: true }));
        IPAccountImpl ipAccount1 = IPAccountImpl(payable(ipId1));

        vm.startPrank(address(module1));
        uint256 policyId1 = licensingModule.registerPolicy(true, policy);
        uint256 policyId2 = licensingModule.registerPolicy(false, policy2); // False to generate new id
        vm.stopPrank();

        // Licensor (IP Account owner) calls directly
        vm.prank(ipAccount1.owner());
        uint256 licenseId = licensingModule.mintLicense(policyId1, ipId1, 1, licenseHolder);
        assertEq(licenseId, 1);

        // Licensor (IP Account owner) calls via IP Account execute
        // The returned license ID (from decoding `result`) should be the same as above, as we're not creating a new
        // license, but rather minting an existing one (existing ID, minted above).
        vm.prank(ipAccount1.owner());
        bytes memory result = ipAccount1.execute(
            address(licensingModule),
            0,
            abi.encodeWithSignature("mintLicense(uint256,address,uint256,address)", policyId1, ipId1, 1, licenseHolder)
        );
        assertEq(1, abi.decode(result, (uint256)));

        // IP Account calls directly
        vm.prank(ipId1);
        licenseId = licensingModule.mintLicense(policyId2, ipId1, 1, licenseHolder);
        assertEq(licenseId, 2); // new license ID as this is the first mint on a different policy
    }

    function test_LicensingModule_linkIpToParents_single_parent() public {
        uint256 licenseId = test_LicensingModule_mintLicense();
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId;

        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, ipOwner, licenseId, 2, "");

        vm.prank(ipOwner);
        licensingModule.linkIpToParents(licenseIds, ipId2, 0);

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

    function test_LicensingModule_singleTransfer_paramVerifyTrue() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);
        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder);
        address licenseHolder2 = address(0x102);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
    }

    function test_LicensingModule_singleTransfer_verifyOk() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = _createPolicy();
        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(true, policy);
        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder);

        address licenseHolder2 = address(0x102);
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 2);
        assertEq(licenseRegistry.balanceOf(licenseHolder2, licenseId), 0);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(licenseRegistry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
        assertEq(licenseRegistry.balanceOf(licenseHolder2, licenseId), 1, "not minted");
    }

    function test_LicensingModule_singleTransfer_revert_verifyFalse() public {
        licensingModule.registerPolicyFrameworkManager(address(module1));
        bytes memory policy = abi.encode(MockPolicy({ returnVerifyLink: true, returnVerifyMint: true }));
        vm.prank(address(module1));
        uint256 policyId = licensingModule.registerPolicy(false, policy);
        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder);

        address licenseHolder2 = address(0x102);
        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
    }

    function test_LicensingModule_licenseUri() public {
        licensingModule.registerPolicyFrameworkManager(address(umlManager));

        UMLPolicy memory policyData = UMLPolicy({
            transferable: true,
            attribution: true,
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
            contentRestrictions: new string[](0),
            royaltyPolicy: address(mockRoyaltyPolicyLS)
        });

        policyData.commercializers[0] = "commercializer1";
        policyData.commercializers[1] = "commercializer2";
        policyData.territories[0] = "territory1";
        policyData.distributionChannels[0] = "distributionChannel1";

        uint256 policyId = umlManager.registerPolicy(policyData);

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 1, licenseHolder);

        string memory actualUri = licenseRegistry.uri(licenseId);

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

        /* solhint-disable */
        string
            memory expectedJson = "eyJuYW1lIjogIlN0b3J5IFByb3RvY29sIExpY2Vuc2UgTkZUIiwgImRlc2NyaXB0aW9uIjogIkxpY2Vuc2UgYWdyZWVtZW50IHN0YXRpbmcgdGhlIHRlcm1zIG9mIGEgU3RvcnkgUHJvdG9jb2wgSVBBc3NldCIsICJhdHRyaWJ1dGVzIjogW3sidHJhaXRfdHlwZSI6ICJBdHRyaWJ1dGlvbiIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIlRyYW5zZmVyYWJsZSIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogIkNvbW1lcmljYWwgVXNlIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiY29tbWVyY2lhbEF0dHJpYnV0aW9uIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiY29tbWVyY2lhbFJldlNoYXJlIiwgInZhbHVlIjogMH0seyJ0cmFpdF90eXBlIjogImNvbW1lcmNpYWxpemVycyIsICJ2YWx1ZSI6IFsiY29tbWVyY2lhbGl6ZXIxIiwiY29tbWVyY2lhbGl6ZXIyIl19LCB7InRyYWl0X3R5cGUiOiAiZGVyaXZhdGl2ZXNBbGxvd2VkIiwgInZhbHVlIjogInRydWUifSx7InRyYWl0X3R5cGUiOiAiZGVyaXZhdGl2ZXNBdHRyaWJ1dGlvbiIsICJ2YWx1ZSI6ICJ0cnVlIn0seyJ0cmFpdF90eXBlIjogImRlcml2YXRpdmVzQXBwcm92YWwiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJkZXJpdmF0aXZlc1JlY2lwcm9jYWwiLCAidmFsdWUiOiAidHJ1ZSJ9LHsidHJhaXRfdHlwZSI6ICJkZXJpdmF0aXZlc1JldlNoYXJlIiwgInZhbHVlIjogMH0seyJ0cmFpdF90eXBlIjogInRlcnJpdG9yaWVzIiwgInZhbHVlIjogWyJ0ZXJyaXRvcnkxIl19LCB7InRyYWl0X3R5cGUiOiAiZGlzdHJpYnV0aW9uQ2hhbm5lbHMiLCAidmFsdWUiOiBbImRpc3RyaWJ1dGlvbkNoYW5uZWwxIl19XX0=";
        /* solhint-enable */

        string memory expectedUri = string(abi.encodePacked("data:application/json;base64,", expectedJson));

        assertEq(actualUri, expectedUri);
    }
}
