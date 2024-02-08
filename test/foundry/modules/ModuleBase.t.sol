// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC6551Registry } from "@erc6551/ERC6551Registry.sol";

import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { AccessController } from "contracts/AccessController.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";

/// @title Module Base Test Contract
/// @notice Base contract for testing standard module functionality.
abstract contract ModuleBaseTest is BaseTest {
    /// @notice Gets the protocol-wide license registry.
    LicenseRegistry public licenseRegistry;

    LicensingModule public licensingModule;

    /// @notice The access controller address.
    AccessController public accessController;

    /// @notice Gets the protocol-wide IP asset registry.
    IPAssetRegistry public ipAssetRegistry;

    /// @notice Gets the protocol-wide module registry.
    ModuleRegistry public moduleRegistry;

    /// @notice The module SUT.
    IModule public baseModule;

    Governance public governance;

    IPMetadataProvider public metadataProvider;

    RoyaltyModule public royaltyModule;

    /// @notice Initializes the base module for testing.
    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();
        governance = new Governance(address(this));
        accessController = new AccessController(address(governance));
        moduleRegistry = new ModuleRegistry(address(governance));

        metadataProvider = new IPMetadataProvider(address(moduleRegistry));
        ipAssetRegistry = new IPAssetRegistry(
            address(accessController),
            address(new ERC6551Registry()),
            address(new IPAccountImpl())
        );
        royaltyModule = new RoyaltyModule(address(governance));
        licenseRegistry = new LicenseRegistry();
        licensingModule = new LicensingModule(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(royaltyModule)
        );
        licenseRegistry.setLicensingModule(address(licensingModule));
        baseModule = IModule(_deployModule());
        accessController.initialize(address(ipAssetRegistry), address(moduleRegistry));
        royaltyModule.setLicensingModule(address(licensingModule));
    }

    /// @notice Tests that the default resolver constructor runs successfully.
    function test_Module_Name() public {
        assertEq(baseModule.name(), _expectedName());
    }

    /// @dev Deploys the module SUT.
    function _deployModule() internal virtual returns (address);

    /// @dev Gets the expected name for the module.
    function _expectedName() internal view virtual returns (string memory);
}
