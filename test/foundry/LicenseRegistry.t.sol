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
}
