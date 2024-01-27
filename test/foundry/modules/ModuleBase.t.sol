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
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
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

    /// @notice Gets the protocol-wide IP account registry.
    IPAccountRegistry public ipAccountRegistry;

    /// @notice Gets the protocol-wide IP record registry.
    IPRecordRegistry public ipRecordRegistry;

    /// @notice Gets the protocol-wide module registry.
    ModuleRegistry public moduleRegistry;

    /// @notice The module SUT.
    IModule public baseModule;

    Governance public governance;

    /// @notice Initializes the base module for testing.
    function setUp() public virtual override(BaseTest) {
        BaseTest.setUp();
        governance = new Governance(address(this));
        licenseRegistry = new LicenseRegistry("");
        accessController = new AccessController(address(governance));
        moduleRegistry = new ModuleRegistry(address(governance));
        ipAccountRegistry = new IPAccountRegistry(
            address(new ERC6551Registry()),
            address(accessController),
            address(new IPAccountImpl())
        );
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
        ipRecordRegistry = new IPRecordRegistry(
            address(moduleRegistry),
            address(ipAccountRegistry)
        );
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
