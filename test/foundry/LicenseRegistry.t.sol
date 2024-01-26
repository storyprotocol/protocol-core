// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { MockParamVerifier } from "test/foundry/mocks/licensing/MockParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "forge-std/console2.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

contract LicenseRegistryTest is Test {
    using Strings for *;
    using ShortStrings for *;

    LicenseRegistry public registry;
    Licensing.Framework public framework;

    MockParamVerifier public verifier1;
    MockParamVerifier public verifier2;
    string public licenseUrl = "https://example.com/license";
    Licensing.FrameworkCreationParams fwParams;
    address public ipId1 = address(0x111);
    address public ipId2 = address(0x222);
    address public licenseHolder = address(0x101);

    function setUp() public {
        registry = new LicenseRegistry("https://example.com/{id}.json");
        verifier1 = new MockParamVerifier(address(registry), "Mock1");
        verifier2 = new MockParamVerifier(address(registry), "Mock2");
    }

    // TODO: add parameter config for initial framework for 100% test
    modifier withFrameworkParams() {
        _initFwParams();
        registry.addLicenseFramework(fwParams);
        _;
    }

    // TODO: use ModuleBaseTest for this
    function _initFwParams() private {
        IParamVerifier[] memory parameters = new IParamVerifier[](1);
        parameters[0] = verifier1;
        bytes[] memory values = new bytes[](1);
        values[0] = abi.encode(true);

        fwParams = Licensing.FrameworkCreationParams({
            parameters: parameters,
            defaultValues: values,
            licenseUrl: licenseUrl
        });
    }

    function _createPolicy() internal view returns (Licensing.Policy memory pol) {
        pol = Licensing.Policy({
            frameworkId: 1,
            commercialUse: true,
            derivatives: true,
            paramNames: new bytes32[](2),
            paramValues: new bytes[](2)
        });
        pol.paramNames[0] = verifier1.name();
        pol.paramValues[0] = abi.encode(true);
        pol.paramNames[1] = verifier2.name();
        pol.paramValues[1] = abi.encode(true);
        return pol;
    }

    function test_LicenseRegistry_addLicenseFramework() public {
        _initFwParams();
        uint256 fwId = registry.addLicenseFramework(fwParams);
        assertEq(fwId, 1, "not incrementing fw id");
        assertTrue(fwParams.licenseUrl.equal(registry.frameworkUrl(fwId)), "licenseUrl not set");
        assertEq(registry.totalFrameworks(), 1, "totalFrameworks not incremented");
        string memory paramName = fwParams.parameters[0].nameString();
        Licensing.Parameter memory storedParam = registry.frameworkParam(1, paramName);
        assertEq(address(storedParam.verifier), address(fwParams.parameters[0]), "verifier not equal");
        // assertEq(address(storedParam.verifier), address(fwParams.parameters[0]), "verifier not equal");
        assertEq(storedParam.defaultValue, fwParams.defaultValues[0], "defaultValue not equal");
    }

    function test_LicenseRegistry_addPolicy() public withFrameworkParams {
        Licensing.Policy memory policy = _createPolicy();
        uint256 polId = registry.addPolicy(policy);
        assertEq(polId, 1, "polId not 1");
    }

    function test_LicenseRegistry_addPolicy_revert_policyAlreadyAdded() public withFrameworkParams {
        Licensing.Policy memory policy = _createPolicy();
        registry.addPolicy(policy);
        vm.expectRevert(Errors.LicenseRegistry__PolicyAlreadyAdded.selector);
        registry.addPolicy(policy);
    }

    function test_LicenseRegistry_addPolicy_revert_frameworkNotFound() public {
        Licensing.Policy memory policy = _createPolicy();
        vm.expectRevert(Errors.LicenseRegistry__FrameworkNotFound.selector);
        registry.addPolicy(policy);
    }

    function test_LicenseRegistry_addPolicyToIpId() public withFrameworkParams {
        Licensing.Policy memory policy = _createPolicy();
        (uint256 policyId, bool isNew, uint256 indexOnIpId) = registry.addPolicyToIp(ipId1, policy);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertFalse(registry.isPolicySetByLinking(ipId1, policyId));
        Licensing.Policy memory storedPolicy = registry.policy(policyId);
        assertEq(keccak256(abi.encode(storedPolicy)), keccak256(abi.encode(policy)), "policy not stored properly");
    }

    function test_LicenseRegistry_addSamePolicyReusesPolicyId() public withFrameworkParams {
        Licensing.Policy memory policy = _createPolicy();
        (uint256 policyId, bool isNew1, uint256 indexOnIpId) = registry.addPolicyToIp(ipId1, policy);
        assertTrue(isNew1, "not new");
        assertEq(indexOnIpId, 0);
        assertFalse(registry.isPolicySetByLinking(ipId1, policyId));
        (uint256 policyId2, bool isNew2, uint256 indexOnIpId2) = registry.addPolicyToIp(ipId2, policy);
        assertFalse(isNew2, "new");
        assertEq(indexOnIpId2, 0);
        assertFalse(registry.isPolicySetByLinking(ipId2, policyId));
        assertEq(policyId, policyId2, "policyId not reused");
    }

    //function test_LicenseRegistry_revert_policyAlreadyAddedToIpId()

    function test_LicenseRegistry_add2PoliciesToIpId() public withFrameworkParams {
        assertEq(registry.totalPolicies(), 0);
        assertEq(registry.totalPoliciesForIp(ipId1), 0);
        Licensing.Policy memory policy = _createPolicy();

        // First time adding a policy
        (uint256 policyId, bool isNew, uint256 indexOnIpId) = registry.addPolicyToIp(ipId1, policy);
        assertTrue(isNew, "not new");
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertEq(registry.totalPolicies(), 1, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(ipId1), 1, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(ipId1, 0), 1, "policyIdForIpAtIndex not 1");
        assertFalse(registry.isPolicySetByLinking(ipId1, policyId));

        // Adding different policy to same ipId
        policy.paramValues[0] = abi.encode("test2");
        (uint256 policyId2, bool isNew2, uint256 indexOnIpId2) = registry.addPolicyToIp(ipId1, policy);
        assertTrue(isNew2, "not new");
        assertEq(policyId2, 2, "policyId not 2");
        assertEq(indexOnIpId2, 1, "indexOnIpId not 1");
        assertEq(registry.totalPolicies(), 2, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(ipId1), 2, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(ipId1, 1), 2, "policyIdForIpAtIndex not 2");
        assertFalse(registry.isPolicySetByLinking(ipId1, policyId2));
    }

    function test_LicenseRegistry_mintLicense() public withFrameworkParams returns (uint256 licenseId) {
        Licensing.Policy memory policy = _createPolicy();
        // solhint-disable-next-line no-unused-vars
        (uint256 policyId, bool isNew, uint256 indexOnIpId) = registry.addPolicyToIp(ipId1, policy);
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

    function test_LicenseRegistry_linkIpToParent() public {
        // TODO: something cleaner than this
        uint256 licenseId = test_LicenseRegistry_mintLicense();

        registry.linkIpToParent(licenseId, ipId2, licenseHolder);
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
        assertEq(registry.isParent(ipId1, ipId2), true, "not parent");
        assertEq(
            keccak256(abi.encode(registry.policyForIpAtIndex(ipId2, 0))),
            keccak256(abi.encode(registry.policyForIpAtIndex(ipId1, 0))),
            "policy not copied"
        );
        assertEq(registry.policyIdForIpAtIndex(ipId2, 0), 1);
        assertTrue(registry.isPolicySetByLinking(ipId2, 1));

        address[] memory parents = registry.parentIpIds(ipId2);
        assertEq(parents.length, 1, "not 1 parent");
        assertEq(
            parents.length,
            registry.totalParentsForIpId(ipId2),
            "parents.length and totalParentsForIpId mismatch"
        );
        assertEq(parents[0], ipId1, "parent not ipId1");
    }

    function test_LicenseRegistry_singleTransfer_paramVerifyTrue() public withFrameworkParams {
        Licensing.Policy memory policy = _createPolicy();

        (uint256 policyId, , ) = registry.addPolicyToIp(ipId1, policy);

        uint256 licenseId = registry.mintLicense(policyId, ipId1, 2, licenseHolder);
        address licenseHolder2 = address(0x102);
        vm.prank(licenseHolder);
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
        assertEq(registry.balanceOf(licenseHolder, licenseId), 1, "not burnt");
    }

    function test_LicenseRegistry_revert_singleTransfer_transferParamVerifyFalse() public withFrameworkParams {
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 1,
            commercialUse: true,
            derivatives: true,
            paramNames: new bytes32[](2),
            paramValues: new bytes[](2)
        });
        policy.paramNames[0] = verifier1.name();
        policy.paramValues[0] = abi.encode(true);
        policy.paramNames[1] = verifier2.name();
        policy.paramValues[1] = abi.encode(false);

        (uint256 policyId, , ) = registry.addPolicyToIp(ipId1, policy);

        uint256 licenseId = registry.mintLicense(policyId, ipId1, 2, licenseHolder);

        address licenseHolder2 = address(0x102);
        vm.prank(licenseHolder);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LicenseRegistry__ParamVerifierFailed.selector,
                uint8(Licensing.ParamVerifierType.Transfer),
                address(verifier1)
            )
        );
        registry.safeTransferFrom(licenseHolder, licenseHolder2, licenseId, 1, "");
    }
}
