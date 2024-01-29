// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ResolverBaseTest } from "test/foundry/resolvers/ResolverBase.t.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { KeyValueResolver } from "contracts/resolvers/KeyValueResolver.sol";
import { IKeyValueResolver } from "contracts/interfaces/resolvers/IKeyValueResolver.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IResolver } from "contracts/interfaces/resolvers/IResolver.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { ModuleBaseTest } from "test/foundry/modules/ModuleBase.t.sol";
import { IP } from "contracts/lib/IP.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";

/// @title IP Resolver Test Contract
/// @notice Tests IP metadata resolver functionality.
contract IPResolverTest is ResolverBaseTest {

    // Test record attributes.
    string public constant TEST_KEY = "Key";
    string public constant TEST_VALUE = "Value";

    /// @notice The registration module.
    address public registrationModule;

    /// @notice The token contract SUT.
    IPResolver public ipResolver;

    /// @notice Mock IP identifier for resolver testing.
    address public ipId;

    /// @notice Initializes the base token contract for testing.
    function setUp() public virtual override(ResolverBaseTest) {
        ResolverBaseTest.setUp();
        MockERC721 erc721 = new MockERC721("Mock");
        vm.prank(alice);
        ipResolver = IPResolver(_deployModule());
        IPMetadataProvider metadataProvider = new IPMetadataProvider(address(moduleRegistry));
        uint256 tokenId = erc721.mintId(alice, 99);
        // TODO: Mock this correctly
        registrationModule = address(new RegistrationModule(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry),
            address(ipResolver),
            address(metadataProvider)
        ));
        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, registrationModule);
        moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));
        vm.prank(registrationModule);
        ipId = ipRecordRegistry.register(
            block.chainid,
            address(erc721),
            tokenId,
            address(ipResolver),
            true,
            address(metadataProvider)
        );
    }

    /// @notice Tests that the IP resolver interface is supported.
    function test_IPMetadataResolver_SupportsInterface() public virtual {
        assertTrue(ipResolver.supportsInterface(type(IKeyValueResolver).interfaceId));
    }

    /// @notice Tests that key-value pair string attribution may be properly set.
    function test_IPMetadataResolver_SetValue() public {
        vm.prank(ipId);
        accessController.setPermission(ipId, alice, address(ipResolver), KeyValueResolver.setValue.selector, 1);
        vm.prank(alice);
        ipResolver.setValue(
            ipId,
            TEST_KEY,
            TEST_VALUE
        );
        assertEq(ipResolver.value(ipId, TEST_KEY), TEST_VALUE);
    }

    /// @dev Gets the expected name for the module.
    function _expectedName() internal virtual view override returns (string memory) {
        return "IP_RESOLVER_MODULE";
    }

    /// @dev Deploys a new IP Metadata Resolver.
    function _deployModule() internal override returns (address) {
        return address(
            new IPResolver(
                address(accessController),
                address(ipRecordRegistry),
                address(ipAccountRegistry),
                address(licenseRegistry)
            )
        );
    }

}
