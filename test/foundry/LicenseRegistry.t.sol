// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { MockIParamVerifier } from "test/foundry/mocks/licensing/MockParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";

contract LicenseRegistryTest is Test {
    LicenseRegistry public registry;
    Licensing.Framework public framework;
    enum VerifierType {
        Minting,
        Activate,
        LinkParent
    }
    MockIParamVerifier public verifier;
    string public licenseUrl = "https://example.com/license";
    Licensing.FrameworkCreationParams fwParams;
    address public ipId1 = address(0x111);
    address public ipId2 = address(0x222);


    modifier withFrameworkParams() {
        _initFwParams();
        registry.addLicenseFramework(fwParams);
        _;
    }

    function _initFwParams() private {
        IParamVerifier[] memory mintingParamVerifiers = new IParamVerifier[](1);
        mintingParamVerifiers[0] = verifier;
        bytes[] memory mintingParamDefaultValues = new bytes[](1);
        mintingParamDefaultValues[0] = abi.encode(true);
        IParamVerifier[] memory activationParamVerifiers = new IParamVerifier[](1);
        activationParamVerifiers[0] = verifier;
        bytes[] memory activationParamDefaultValues = new bytes[](1);
        activationParamDefaultValues[0] = abi.encode(true);
        IParamVerifier[] memory linkParentParamVerifiers = new IParamVerifier[](1);
        linkParentParamVerifiers[0] = verifier;
        bytes[] memory linkParentParamDefaultValues = new bytes[](1);
        linkParentParamDefaultValues[0] = abi.encode(true);

        fwParams = Licensing.FrameworkCreationParams({
            mintingParamVerifiers: mintingParamVerifiers,
            mintingParamDefaultValues: mintingParamDefaultValues,
            activationParamVerifiers: activationParamVerifiers,
            activationParamDefaultValues: activationParamDefaultValues,
            defaultNeedsActivation: true,
            linkParentParamVerifiers: linkParentParamVerifiers,
            linkParentParamDefaultValues: linkParentParamDefaultValues,
            licenseUrl: licenseUrl
        });
    }

    function setUp() public {
        verifier = new MockIParamVerifier();
        registry = new LicenseRegistry("https://example.com/{id}.json");
    }

    function test_LicenseRegistry_addLicenseFramework() public {
        _initFwParams();
        registry.addLicenseFramework(fwParams);
        assertEq(keccak256(abi.encode(registry.framework(0))), keccak256(abi.encode(framework)), "framework not added");
        assertEq(registry.totalFrameworks(), 1, "total frameworks not updated");
    }

    function test_LicenseRegistry_addPolicyId() public withFrameworkParams {
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 0,
            mintingParamValues: new bytes[](1),
            activationParamValues: new bytes[](1),
            needsActivation: false,
            linkParentParamValues: new bytes[](1)
        });
        policy.mintingParamValues[0] = abi.encode("test");
        policy.activationParamValues[0] = abi.encode("test");
        policy.linkParentParamValues[0] = abi.encode("test");
        (uint256 policyId, uint256 indexOnIpId) = registry.addPolicy(ipId1, policy);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        Licensing.Policy memory storedPolicy = registry.policy(policyId);
        assertEq(keccak256(abi.encode(storedPolicy)), keccak256(abi.encode(policy)), "policy not stored properly");

    }

    function test_LicenseRegistry_addSamePolicyReusesPolicyId() public withFrameworkParams {
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 0,
            mintingParamValues: new bytes[](1),
            activationParamValues: new bytes[](1),
            needsActivation: false,
            linkParentParamValues: new bytes[](1)
        });
        policy.mintingParamValues[0] = abi.encode("test");
        policy.activationParamValues[0] = abi.encode("test");
        policy.linkParentParamValues[0] = abi.encode("test");
        (uint256 policyId, uint256 indexOnIpId) = registry.addPolicy(ipId1, policy);
        (uint256 policyId2, uint256 indexOnIpId2) = registry.addPolicy(ipId2, policy);
        assertEq(policyId, policyId2, "policyId not reused");
    }

    //function test_LicenseRegistry_revert_policyAlreadyAddedToIpId()

    function test_LicenseRegistry_add2PoliciesToIpId() public withFrameworkParams {
        assertEq(registry.totalPolicies(), 0);
        assertEq(registry.totalPoliciesForIp(ipId1), 0);
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 0,
            mintingParamValues: new bytes[](1),
            activationParamValues: new bytes[](1),
            needsActivation: false,
            linkParentParamValues: new bytes[](1)
        });
        policy.mintingParamValues[0] = abi.encode("test");
        policy.activationParamValues[0] = abi.encode("test");
        policy.linkParentParamValues[0] = abi.encode("test");

        // First time adding a policy
        (uint256 policyId, uint256 indexOnIpId) = registry.addPolicy(ipId1, policy);
        assertEq(policyId, 1, "policyId not 1");
        assertEq(indexOnIpId, 0, "indexOnIpId not 0");
        assertEq(registry.totalPolicies(), 1, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(ipId1), 1, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(ipId1, 0), 1, "policyIdForIpAtIndex not 1");

        // Adding different policy to same ipId
        policy.mintingParamValues[0] = abi.encode("test2");
        (uint256 policyId2, uint256 indexOnIpId2) = registry.addPolicy(ipId1, policy);
        assertEq(policyId2, 2, "policyId not 2");
        assertEq(indexOnIpId2, 1, "indexOnIpId not 1");
        assertEq(registry.totalPolicies(), 2, "totalPolicies not incremented");
        assertEq(registry.totalPoliciesForIp(ipId1), 2, "totalPoliciesForIp not incremented");
        assertEq(registry.policyIdForIpAtIndex(ipId1, 1), 2, "policyIdForIpAtIndex not 2");
    }

}