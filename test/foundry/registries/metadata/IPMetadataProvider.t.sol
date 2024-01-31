// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IP Metadata Provider Testing Contract
/// @notice Contract for metadata provider settings.
contract IPMetadataProviderTest is BaseTest {

    /// @notice Test bytes metadata settings.
    bytes public TEST_METADATA = bytes("DEADBEEF");

    /// @notice Placeholder for module registry.
    MockModuleRegistry public registry;

    /// @notice Placeholder or registration module.
    address public registrationModule = vm.addr(0x69);

    /// @notice Placeholder for an IP id.
    address public ipId = vm.addr(0x1234);

    /// @notice The IP metadata provider SUT.
    IPMetadataProvider public metadataProvider;

    /// @notice Initializes the IP metadata provider contract.
    function setUp() public virtual override {
        BaseTest.setUp();
        registry = new MockModuleRegistry(registrationModule);
        metadataProvider = new IPMetadataProvider(address(registry));
    }

    /// @notice Tests IP metadata provider initialization.
    function test_IPMetadataProvider_Constructor() public {
        assertEq(address(metadataProvider.MODULE_REGISTRY()), address(registry));
    }

    /// @notice Tests metadata is properly stored.
    function test_IPMetadataProvider_Metadata() public {
        vm.prank(registrationModule);
        metadataProvider.setMetadata(ipId, TEST_METADATA);
        bytes memory expectedMetadata = bytes("DEADBEEF");
        assertEq(
            metadataProvider.getMetadata(ipId),
            expectedMetadata
        );
    }
}
