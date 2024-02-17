// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// contracts
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { RegisterUMLPolicyParams } from "contracts/interfaces/modules/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// test
// solhint-disable-next-line max-line-length
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig, MockPolicy } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
import { MockAccessController } from "test/foundry/mocks/access/MockAccessController.sol";
import { MockTokenGatedHook } from "test/foundry/mocks/MockTokenGatedHook.sol";
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
    }

    function _createMockPolicy() internal pure returns (bytes memory) {
        return abi.encode(MockPolicy({ returnVerifyLink: true, returnVerifyMint: true }));
    }

    function _createPolicyFrameworkData() internal view returns (Licensing.Policy memory) {
        return Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: address(mockPFM),
            frameworkData: _createMockPolicy(),
            royaltyPolicy: address(mockRoyaltyPolicyLAP),
            royaltyData: "",
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
    }

    function test_LicensingModule_registerLicenseFramework() public {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));
        assertTrue(licensingModule.isFrameworkRegistered(address(mockPFM)), "framework not registered");
    }

    function test_LicensingModule_registerPolicy() public withPolicyFrameworkManager {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());
        assertEq(policyId, 1, "policyId not 1");
    }

    function test_LicensingModule_registerPolicy_reusesIdForAlreadyAddedPolicy() public withPolicyFrameworkManager {
        vm.startPrank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());
        assertEq(policyId, licensingModule.registerPolicy(_createPolicyFrameworkData()));
        vm.stopPrank();
    }

    function test_LicensingModule_getPolicyId() public withPolicyFrameworkManager {
        bytes memory policy = _createMockPolicy();
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());
        Licensing.Policy memory storedPolicy = licensingModule.policy(policyId);
        assertEq(licensingModule.getPolicyId(storedPolicy), policyId, "policyId not found");
    }

    function test_LicensingModule_registerPolicy_revert_frameworkNotFound() public {
        vm.expectRevert(Errors.LicensingModule__FrameworkNotFound.selector);
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());
    }

    function test_LicensingModule_addPolicyToIpId() public withPolicyFrameworkManager {
        Licensing.Policy memory policy = _createPolicyFrameworkData();
        vm.prank(u.admin);
        royaltyModule.whitelistRoyaltyToken(address(0x123), true);
        policy.mintingFee = 123;
        policy.mintingFeeToken = address(0x123);
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(policy);

        vm.prank(ipOwner);
        uint256 indexOnIpId = licensingModule.addPolicyToIp(ipId1, policyId);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertFalse(licensingModule.isPolicyInherited(ipId1, policyId));

        Licensing.Policy memory storedPolicy = licensingModule.policy(policyId);
        assertEq(storedPolicy.policyFramework, address(mockPFM), "policyFramework not stored properly");
        assertEq(storedPolicy.royaltyPolicy, address(mockRoyaltyPolicyLAP), "royaltyPolicy not stored properly");
        assertEq(storedPolicy.isLicenseTransferable, true, "isLicenseTransferable not stored properly");
        assertEq(storedPolicy.frameworkData, policy.frameworkData, "frameworkData not stored properly");
        assertEq(storedPolicy.royaltyData, "", "royaltyData not stored properly");
        assertEq(storedPolicy.mintingFee, 123, "mintingFee not stored properly");
        assertEq(storedPolicy.mintingFeeToken, address(0x123), "mintingFeeToken not stored properly");
        assertEq(keccak256(abi.encode(storedPolicy)), keccak256(abi.encode(policy)), "policy not stored properly");
    }

    function test_LicensingModule_addSamePolicyReusesPolicyId() public withPolicyFrameworkManager {
        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());

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
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());
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
        Licensing.Policy memory otherPolicy = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: address(mockPFM),
            frameworkData: abi.encode("something"),
            royaltyPolicy: address(mockRoyaltyPolicyLAP),
            royaltyData: "",
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
        vm.prank(address(mockPFM));
        uint256 policyId2 = licensingModule.registerPolicy(otherPolicy);
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
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());
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
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        vm.expectRevert(Errors.LicensingModule__LicensorNotRegistered.selector);
        licensingModule.mintLicense(policyId, address(0), 2, licenseHolder, "");
    }

    function test_LicensingModule_mintLicense_revert_callerNotLicensorAndIpIdHasNoPolicy() public {
        licensingModule.registerPolicyFrameworkManager(address(mockPFM));

        IIPAccount ipAccount1 = IIPAccount(payable(ipId1));

        vm.prank(address(mockPFM));
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());

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
        IIPAccount ipAccount1 = IIPAccount(payable(ipId1));

        vm.startPrank(address(mockPFM));
        uint256 policyId1 = licensingModule.registerPolicy(_createPolicyFrameworkData());
        Licensing.Policy memory pol2 = _createPolicyFrameworkData();
        pol2.isLicenseTransferable = false;
        uint256 policyId2 = licensingModule.registerPolicy(pol2);
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
        uint256 policyId = licensingModule.registerPolicy(_createPolicyFrameworkData());

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
        
        Licensing.Policy memory pol = _createPolicyFrameworkData();
        pol.isLicenseTransferable = false;
        uint256 policyId = licensingModule.registerPolicy(pol);

        vm.prank(ipOwner);
        licensingModule.addPolicyToIp(ipId1, policyId);

        uint256 licenseId = licensingModule.mintLicense(policyId, ipId1, 2, licenseHolder, "");

        address licenseHolder2 = address(0x102);
        vm.expectRevert(Errors.LicenseRegistry__NotTransferable.selector);
        vm.prank(licenseHolder);
        licenseRegistry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
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
                royaltyPolicy: address(mockRoyaltyPolicyLAP),
                mintingFee: 0,
                mintingFeeToken: address(0),
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
