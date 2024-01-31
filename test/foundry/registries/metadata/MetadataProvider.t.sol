// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { MetadataProviderV1 } from "contracts/registries/metadata/MetadataProviderV1.sol";
import { IMetadataProvider } from "contracts/interfaces/registries/metadata/IMetadataProvider.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IP Metadata Provider Testing Contract
/// @notice Contract for metadata provider settings.
contract MetadataProviderTest is BaseTest {

    /// @notice Test bytes metadata settings.
    bytes public TEST_METADATA = bytes("DEADBEEF");

    /// @notice Placeholder for IP asset registry.
    address public registry = vm.addr(0x1212);

    /// @notice Placeholder or registration module.
    address public registrationModule = vm.addr(0x69);

    /// @notice Placeholder for an IP id.
    address public ipId = vm.addr(0x1234);

    /// @notice The IP metadata provider SUT.
    MetadataProviderV1 public metadataProvider;

    /// @notice Initializes the IP metadata provider contract.
    function setUp() public virtual override {
        BaseTest.setUp();
        metadataProvider = new MetadataProviderV1(address(registry));
    }

    /// @notice Tests IP metadata provider initialization.
    function test_MetadataProvider_Constructor() public {
        assertEq(address(metadataProvider.IP_ASSET_REGISTRY()), registry);
    }

    /// @notice Tests metadata is properly stored.
    function test_MetadataProvider_Metadata() public {
        vm.prank(registrationModule);
        metadataProvider.setMetadata(ipId, TEST_METADATA);
        bytes memory expectedMetadata = bytes("DEADBEEF");
        assertEq(
            metadataProvider.getMetadata(ipId),
            expectedMetadata
        );
    }

    /// @notice Checks that metadata setting reverts if not called by the registry.
    function test_MetadataProvider_SetMetadata_Reverts_Unauthorized() public {
        vm.expectRevert(Errors.MetadataProvider__Unauthorized.selector);
        metadataProvider.setMetadata(ipId, TEST_METADATA);
    }
}
