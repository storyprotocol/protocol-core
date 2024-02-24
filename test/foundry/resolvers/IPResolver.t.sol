// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ResolverBaseTest } from "test/foundry/resolvers/ResolverBase.t.sol";
import { KeyValueResolver } from "contracts/resolvers/KeyValueResolver.sol";
import { IKeyValueResolver } from "contracts/interfaces/resolvers/IKeyValueResolver.sol";
import { IP } from "contracts/lib/IP.sol";
import { IP_RESOLVER_MODULE_KEY } from "contracts/lib/modules/Module.sol";

/// @title IP Resolver Test Contract
/// @notice Tests IP metadata resolver functionality.
contract IPResolverTest is ResolverBaseTest {
    // Test record attributes.
    string public constant TEST_KEY = "Key";
    string public constant TEST_VALUE = "Value";

    /// @notice Mock IP identifier for resolver testing.
    address public ipId;

    /// @notice Initial metadata to set for testing.
    bytes public metadata;

    /// @notice Initializes the base token contract for testing.
    function setUp() public virtual override(ResolverBaseTest) {
        ResolverBaseTest.setUp();

        uint256 tokenId = mockNFT.mintId(alice, 99);
        moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));

        metadata = abi.encode(
            IP.MetadataV1({
                name: "IP_NAME",
                hash: "0x99",
                registrationDate: uint64(block.timestamp),
                registrant: alice,
                uri: "https://storyprotocol.xyz"
            })
        );
        vm.prank(alice);
        ipId = ipAssetRegistry.register(block.chainid, address(mockNFT), tokenId, address(ipResolver), true, metadata);
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
        ipResolver.setValue(ipId, TEST_KEY, TEST_VALUE);
        assertEq(ipResolver.value(ipId, TEST_KEY), TEST_VALUE);
    }

    /// @dev Gets the expected name for the module.
    function _expectedName() internal view virtual override returns (string memory) {
        return "IP_RESOLVER_MODULE";
    }

    /// @dev Deploys a new IP Metadata Resolver.
    function _deployModule() internal view override returns (address) {
        return address(ipResolver);
    }
}
