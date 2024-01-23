// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { MockIParamVerifier } from "test/foundry/mocks/licensing/MockParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract LicenseRegistryTest is Test {
    using Strings for *;

    LicenseRegistry public registry;
    Licensing.Framework public framework;

    MockIParamVerifier public verifier;
    string public licenseUrl = "https://example.com/license";
    Licensing.FrameworkCreationParams fwParams;
    address public ipId1 = address(0x111);
    address public ipId2 = address(0x222);
    address public licenseHolder = address(0x101);

    // TODO: add parameter config for initial framework for 100% test
    modifier withFrameworkParams() {
        _initFwParams();
        registry.addLicenseFramework(fwParams);
        _;
    }
    // TODO: use ModuleBaseTest for this
    function _initFwParams() private {
        IParamVerifier[] memory mintingVerifiers = new IParamVerifier[](1);
        mintingVerifiers[0] = verifier;
        bytes[] memory mintingDefaultValues = new bytes[](1);
        mintingDefaultValues[0] = abi.encode(true);
        IParamVerifier[] memory activationVerifiers = new IParamVerifier[](1);
        activationVerifiers[0] = verifier;
        bytes[] memory activationDefaultValues = new bytes[](1);
        activationDefaultValues[0] = abi.encode(true);
        IParamVerifier[] memory linkParentVerifiers = new IParamVerifier[](1);
        linkParentVerifiers[0] = verifier;
        bytes[] memory linkParentDefaultValues = new bytes[](1);
        linkParentDefaultValues[0] = abi.encode(true);
        IParamVerifier[] memory transferVerifiers = new IParamVerifier[](1);
        transferVerifiers[0] = verifier;
        bytes[] memory transferDefaultValues = new bytes[](1);
        transferDefaultValues[0] = abi.encode(true);

        fwParams = Licensing.FrameworkCreationParams({
            mintingVerifiers: mintingVerifiers,
            mintingDefaultValues: mintingDefaultValues,
            activationVerifiers: activationVerifiers,
            activationDefaultValues: activationDefaultValues,
            mintsActiveByDefault: true,
            linkParentVerifiers: linkParentVerifiers,
            linkParentDefaultValues: linkParentDefaultValues,
            transferVerifiers: transferVerifiers,
            transferDefaultValues: transferDefaultValues,
            licenseUrl: licenseUrl
        });
    }

    function setUp() public {
        verifier = new MockIParamVerifier();
        registry = new LicenseRegistry("https://example.com/{id}.json");
    }

    function test_LicenseRegistry_addLicenseFramework() public {
        _initFwParams();
        uint256 fwId = registry.addLicenseFramework(fwParams);
        assertEq(fwId, 1, "not incrementing fw id");
        assertTrue(fwParams.licenseUrl.equal(registry.frameworkUrl(fwId)), "licenseUrl not set");
        assertEq(registry.totalFrameworks(), 1, "totalFrameworks not incremented");
        assertEq(registry.frameworkMintsActiveByDefault(fwId), fwParams.mintsActiveByDefault);
        assertEq(registry.frameworkParams(fwId, Licensing.ParamVerifierType.Minting).length, 1);
        assertEq(registry.totalFrameworks(), 1, "total frameworks not updated");
        _assertEqualParams(
            registry.frameworkParams(fwId, Licensing.ParamVerifierType.Minting),
            fwParams.mintingVerifiers,
            fwParams.mintingDefaultValues
        );
        _assertEqualParams(
            registry.frameworkParams(fwId, Licensing.ParamVerifierType.Activation),
            fwParams.activationVerifiers,
            fwParams.activationDefaultValues
        );
        _assertEqualParams(
            registry.frameworkParams(fwId, Licensing.ParamVerifierType.LinkParent),
            fwParams.linkParentVerifiers,
            fwParams.linkParentDefaultValues
        );
        _assertEqualParams(
            registry.frameworkParams(fwId, Licensing.ParamVerifierType.Transfer),
            fwParams.transferVerifiers,
            fwParams.transferDefaultValues
        );
    }

    function _assertEqualParams(
        Licensing.Parameter[] memory params1,
        IParamVerifier[] memory verifiers,
        bytes[] memory defaultValues
    ) private {
        assertEq(params1.length, verifiers.length, "length mismatch");
        assertEq(params1.length, defaultValues.length, "length mismatch");
        for (uint256 i = 0; i < params1.length; i++) {
            assertEq(address(params1[i].verifier), address(verifiers[i]), "verifier mismatch");
            assertEq(params1[i].defaultValue, defaultValues[i], "default value mismatch");
        }
    }

    function test_LicenseRegistry_addPolicyToIpId() public withFrameworkParams {
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 1,
            mintingParamValues: new bytes[](1),
            activationParamValues: new bytes[](1),
            needsActivation: false,
            linkParentParamValues: new bytes[](1)
        });
        policy.mintingParamValues[0] = abi.encode(true);
        policy.activationParamValues[0] = abi.encode(true);
        policy.linkParentParamValues[0] = abi.encode(true);
        (uint256 policyId, bool isNew, uint256 indexOnIpId) = registry.addPolicyToIp(ipId1, policy);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        Licensing.Policy memory storedPolicy = registry.policy(policyId);
        assertEq(keccak256(abi.encode(storedPolicy)), keccak256(abi.encode(policy)), "policy not stored properly");
    }

    function test_LicenseRegistry_addSamePolicyReusesPolicyId() public withFrameworkParams {
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 1,
            mintingParamValues: new bytes[](1),
            activationParamValues: new bytes[](1),
            needsActivation: false,
            linkParentParamValues: new bytes[](1)
        });
        policy.mintingParamValues[0] = abi.encode(true);
        policy.activationParamValues[0] = abi.encode(true);
        policy.linkParentParamValues[0] = abi.encode(true);
        (uint256 policyId, bool isNew1, uint256 indexOnIpId) = registry.addPolicyToIp(ipId1, policy);
        (uint256 policyId2, bool isNew2, uint256 indexOnIpId2) = registry.addPolicyToIp(ipId2, policy);
        assertEq(policyId, policyId2, "policyId not reused");
    }

    //function test_LicenseRegistry_revert_policyAlreadyAddedToIpId()

    function test_LicenseRegistry_add2PoliciesToIpId() public withFrameworkParams {
        assertEq(registry.totalPolicies(), 0);
        assertEq(registry.totalPoliciesForIp(ipId1), 0);
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 1,
            mintingParamValues: new bytes[](1),
            activationParamValues: new bytes[](1),
            needsActivation: false,
            linkParentParamValues: new bytes[](1)
        });
        policy.mintingParamValues[0] = abi.encode(true);
        policy.activationParamValues[0] = abi.encode(true);
        policy.linkParentParamValues[0] = abi.encode(true);

        // First time adding a policy
        (uint256 policyId, bool isNew, uint256 indexOnIpId) = registry.addPolicyToIp(ipId1, policy);
        // TODO: test isNew
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertEq(registry.totalPolicies(), 1, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(ipId1), 1, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(ipId1, 0), 1, "policyIdForIpAtIndex not 1");

        // Adding different policy to same ipId
        policy.mintingParamValues[0] = abi.encode("test2");
        (uint256 policyId2, bool isNew2, uint256 indexOnIpId2) = registry.addPolicyToIp(ipId1, policy);
        assertEq(policyId2, 2, "policyId not 2");
        assertEq(indexOnIpId2, 1, "indexOnIpId not 1");
        assertEq(registry.totalPolicies(), 2, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(ipId1), 2, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(ipId1, 1), 2, "policyIdForIpAtIndex not 2");
    }

    function test_LicenseRegistry_mintLicense() public withFrameworkParams returns (uint256 licenseId) {
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 1,
            mintingParamValues: new bytes[](1),
            activationParamValues: new bytes[](1),
            needsActivation: false,
            linkParentParamValues: new bytes[](1)
        });
        policy.mintingParamValues[0] = abi.encode(true);
        policy.activationParamValues[0] = abi.encode(true);
        policy.linkParentParamValues[0] = abi.encode(true);

        (uint256 policyId, bool isNew, uint256 indexOnIpId) = registry.addPolicyToIp(ipId1, policy);
        assertEq(policyId, 1);
        assertTrue(registry.isPolicyIdSetForIp(ipId1, policyId));

        uint256[] memory policyIds = registry.policyIdsForIp(ipId1);
        assertEq(policyIds.length, 1);
        assertEq(policyIds[indexOnIpId], policyId);

        Licensing.License memory licenseData = Licensing.License({
            policyId: policyId,
            licensorIpIds: new address[](1)
        });
        licenseData.licensorIpIds[0] = ipId1;

        licenseId = registry.mintLicense(licenseData, 2, licenseHolder);
        assertEq(licenseId, 1);
        assertEq(registry.balanceOf(licenseHolder, licenseId), 2);
        assertEq(registry.isLicensee(licenseId, licenseHolder), true);
        return licenseId;
    }

    function test_LicenseRegistry_setParentId() public {
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

        address[] memory parents = registry.parentIpIds(ipId2);
        assertEq(parents.length, 1, "not 1 parent");
        assertEq(
            parents.length,
            registry.totalParentsForIpId(ipId2),
            "parents.length and totalParentsForIpId mismatch"
        );
        assertEq(parents[0], ipId1, "parent not ipId1");
    }
}
