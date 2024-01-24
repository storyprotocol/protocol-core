// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { ModuleBaseTest } from "./ModuleBase.t.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPMetadataResolver } from "contracts/resolvers/IPMetadataResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { IIPMetadataResolver } from "contracts/interfaces/resolvers/IIPMetadataResolver.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { MockIParamVerifier } from "test/foundry/mocks/licensing/MockParamVerifier.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IP } from "contracts/lib/IP.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { METADATA_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";

/// @title IP Registration Module Test Contract
/// @notice Tests IP registration module functionality.
contract RegistrationModuleTest is ModuleBaseTest {

    // Default IP record attributes.
    string public constant RECORD_NAME = "IPRecord";
    string public constant RECORD_DESCRIPTION = "IPs all the way down.";
    bytes32 public constant RECORD_HASH = "";

    /// @notice The registration module SUT.
    RegistrationModule public registrationModule;

    /// @notice Gets the IP metadata resolver tied to the registration module.
    IIPMetadataResolver public resolver;

    /// @notice Mock NFT address for IP registration testing.
    address public tokenAddress;

    /// @notice Mock NFT tokenId for IP registration testing.
    uint256 public tokenId;

    /// @notice Alternative NFT tokenId for IP registration testing.
    uint256 public tokenId2;

    /// @notice Policy Id with mocked terms for IP registration testing.
    uint256 public policyId;

    /// @notice Initializes the base token contract for testing.
    function setUp() public virtual override(ModuleBaseTest) {
        ModuleBaseTest.setUp();
        _initLicensing();
        resolver = new IPMetadataResolver(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry)
        );
        registrationModule = RegistrationModule(_deployModule());
        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        moduleRegistry.registerModule(METADATA_RESOLVER_MODULE_KEY, address(resolver));
        MockERC721 erc721 = new MockERC721();
        tokenAddress = address(erc721);
        tokenId = erc721.mintId(alice, 99);
        tokenId2 = erc721.mintId(bob, 100);
    }

    /// @notice Checks that the registration initialization operates correctly.
    function test_RegistrationModule_Constructor() public {
        assertEq(address(registrationModule.ACCESS_CONTROLLER()), address(accessController));
        assertEq(address(registrationModule.IP_ACCOUNT_REGISTRY()), address(ipAccountRegistry));
        assertEq(address(registrationModule.IP_RECORD_REGISTRY()), address(ipRecordRegistry));
        assertEq(address(registrationModule.LICENSE_REGISTRY()), address(licenseRegistry));
        assertEq(address(registrationModule.resolver()), address(resolver));
    }

    /// @notice Checks whether root IP registration operates as expected.
    function test_RegistrationModule_RegisterRootIP() public {
        uint256 totalSupply = ipRecordRegistry.totalSupply();
        address ipId = ipRecordRegistry.ipId(block.chainid, tokenAddress, tokenId);

        // Ensure unregistered IP preconditions are satisfied.
        assertTrue(!ipRecordRegistry.isRegistered(ipId));
        assertTrue(!ipRecordRegistry.isRegistered(block.chainid, tokenAddress, tokenId));
        assertTrue(!IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
        
        vm.startPrank(alice);
        registrationModule.registerRootIp(
            policyId,
            tokenAddress,
            tokenId
        );
        vm.stopPrank();

        /// Ensure registered IP postconditiosn are met.
        assertEq(ipRecordRegistry.resolver(ipId), address(resolver));
        assertEq(totalSupply + 1, ipRecordRegistry.totalSupply());
        assertTrue(ipRecordRegistry.isRegistered(ipId));
        assertTrue(ipRecordRegistry.isRegistered(block.chainid, tokenAddress, tokenId));
        assertTrue(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId));
    }

    /// @notice Checks that registration reverts when called by an invalid owner.
    function test_RegistrationModule_RegisterRootIP_Reverts_InvalidOwner() public {
        vm.expectRevert(Errors.RegistrationModule__InvalidOwner.selector);
        registrationModule.registerRootIp(
            0,
            tokenAddress,
            tokenId
        );
    }

    /// @notice Checks whether root IP registration operates as expected.
    function test_RegistrationModule_RegisterDerivativeIP() public {
        // Register root IP with policyId
        vm.prank(alice);
        address ipId = registrationModule.registerRootIp(
            policyId,
            tokenAddress,
            tokenId
        );

        // Mint license
        address[] memory licensorIpIds = new address[](1);
        licensorIpIds[0] = ipId;
        uint256 licenseId = licenseRegistry.mintLicense(policyId, licensorIpIds, 1, bob);
        uint256 totalSupply = ipRecordRegistry.totalSupply();
        

        // Ensure unregistered IP preconditions are satisfied.
        address ipId2 = ipRecordRegistry.ipId(block.chainid, tokenAddress, tokenId2);

        assertFalse(ipRecordRegistry.isRegistered(ipId2), "IP is already registered");
        assertFalse(ipRecordRegistry.isRegistered(block.chainid, tokenAddress, tokenId2), "IP is already registered");
        assertFalse(IPAccountChecker.isRegistered(ipAccountRegistry, block.chainid, tokenAddress, tokenId2), "IP is already registered");

        vm.prank(bob);
        registrationModule.registerDerivativeIp(
            licenseId,
            tokenAddress,
            tokenId2,
            RECORD_NAME,
            RECORD_DESCRIPTION,
            RECORD_HASH
        );


        /// Ensur registered IP post-conditions are met.
        assertEq(ipRecordRegistry.resolver(ipId2), address(resolver));
        assertEq(totalSupply + 1, ipRecordRegistry.totalSupply());
        assertTrue(ipRecordRegistry.isRegistered(ipId2));
        assertTrue(ipRecordRegistry.isRegistered(block.chainid, tokenAddress, tokenId2));
        assertEq(resolver.name(ipId2), RECORD_NAME);
        assertEq(resolver.description(ipId2), RECORD_DESCRIPTION);
        assertEq(resolver.hash(ipId2), RECORD_HASH);
        assertEq(resolver.owner(ipId2), bob);
    }

    /// @notice Checks that registration reverts when called by an invalid owner.
    function test_RegistrationModule_ARegisterDerivativeIP_Reverts_InvalidOwner() public {
        vm.expectRevert(Errors.RegistrationModule__InvalidOwner.selector);
        registrationModule.registerDerivativeIp(
            0,
            tokenAddress,
            tokenId,
            RECORD_NAME,
            RECORD_DESCRIPTION,
            RECORD_HASH
        );
    }

    /// @dev Deploys the registration module SUT.
    function _deployModule() internal virtual override returns (address) {
        return address(
            new RegistrationModule(
                address(accessController),
                address(ipRecordRegistry),
                address(ipAccountRegistry),
                address(licenseRegistry),
                address(resolver)
            )
        );
    }

    /// @dev Gets the expected name for the module.
    function _expectedName() internal virtual view override returns (string memory) {
        return "REGISTRATION_MODULE";
    }

    // TODO: put this in the base test
    function _initLicensing() private {
        IParamVerifier[] memory mintingVerifiers = new IParamVerifier[](1);
        MockIParamVerifier verifier = new MockIParamVerifier();
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

        Licensing.FrameworkCreationParams memory fwParams = Licensing.FrameworkCreationParams({
            mintingVerifiers: mintingVerifiers,
            mintingDefaultValues: mintingDefaultValues,
            activationVerifiers: activationVerifiers,
            activationDefaultValues: activationDefaultValues,
            mintsActiveByDefault: true,
            linkParentVerifiers: linkParentVerifiers,
            linkParentDefaultValues: linkParentDefaultValues,
            transferVerifiers: new IParamVerifier[](0),
            transferDefaultValues: new bytes[](0),
            licenseUrl: "https://example.com"
        });
        licenseRegistry.addLicenseFramework(fwParams);
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 1,
            mintingParamValues: new bytes[](1),
            activationParamValues: new bytes[](1),
            mintsActive: false,
            linkParentParamValues: new bytes[](1),
            transferParamValues: new bytes[](1)
        });
        policy.mintingParamValues[0] = abi.encode(true);
        policy.activationParamValues[0] = abi.encode(true);
        policy.linkParentParamValues[0] = abi.encode(true);
        policy.transferParamValues[0] = abi.encode(true);
        (uint256 polId) = licenseRegistry.addPolicy(policy);
        
        policyId = polId;
    }

}
