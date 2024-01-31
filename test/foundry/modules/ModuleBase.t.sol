// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { BaseModule } from "contracts/modules/BaseModule.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { AccessController } from "contracts/AccessController.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { IP } from "contracts/lib/IP.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Governance } from "contracts/governance/Governance.sol";

/// @title Module Base Test Contract
/// @notice Base contract for testing standard module functionality.
abstract contract ModuleBaseTest is BaseTest {

    /// @notice Gets the protocol-wide license registry.
    LicenseRegistry public licenseRegistry;

    /// @notice The access controller address.
    AccessController public accessController;

    /// @notice Gets the protocol-wide IP asset registry.
    IPAssetRegistry public ipAssetRegistry;

    /// @notice Gets the protocol-wide module registry.
    ModuleRegistry public moduleRegistry;

    /// @notice The module SUT.
    IModule public baseModule;

    Governance public governance;

    IPMetadataProvider metadataProvider;

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
            address(new IPAccountImpl()),
            address(metadataProvider)
        );
        accessController.initialize(address(ipAssetRegistry), address(moduleRegistry));
        licenseRegistry = new LicenseRegistry(address(accessController), address(ipAssetRegistry));
        baseModule = IModule(_deployModule());
    }

    /// @notice Tests that the default resolver constructor runs successfully.
    function test_Module_Name() public {
        assertEq(baseModule.name(), _expectedName());
    }

    /// @dev Deploys the module SUT.
    function _deployModule() internal virtual returns (address);

    /// @dev Gets the expected name for the module.
    function _expectedName() internal virtual view returns (string memory);

}
