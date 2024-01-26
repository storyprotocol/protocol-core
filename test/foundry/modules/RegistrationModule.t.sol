// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { ModuleBaseTest } from "./ModuleBase.t.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { IModuleRegistry } from "contracts/interfaces/registries/IModuleRegistry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { MockModuleRegistry } from "test/foundry/mocks/MockModuleRegistry.sol";
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
import { IPAccountImpl} from "contracts/IPAccountImpl.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { MockIParamVerifier } from "test/foundry/mocks/licensing/MockParamVerifier.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IP } from "contracts/lib/IP.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";

/// @title IP Registration Module Test Contract
/// @notice Tests IP registration module functionality.
contract RegistrationModuleTest is ModuleBaseTest {

    // Default IP record attributes.
    string public constant RECORD_NAME = "IPRecord";
    bytes32 public constant RECORD_HASH = "";
    string public constant RECORD_URL = "https://ipasset.xyz";

    /// @notice IP metadata rendering contract.
    IPAssetRenderer public renderer;

    /// @notice The Story Protocol default IP resolver.
    IPResolver public resolver;

    /// @notice The registration module SUT.
    RegistrationModule public registrationModule;

    /// @notice Gets the contract responsible for IP metadata provisioning.
    IPMetadataProvider public metadataProvider;

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
        resolver = new IPResolver(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry)
        );
        metadataProvider = new IPMetadataProvider(address(moduleRegistry));
        registrationModule = RegistrationModule(_deployModule());
        renderer = new IPAssetRenderer(
            address(ipRecordRegistry),
            address(licenseRegistry),
            vm.addr(0x1111), // TODO: Incorporate tagging module into renderer.
            vm.addr(0x2111) // TODO: Incorporate royalty module into renderer.
        );
        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(resolver));
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
        assertEq(ipRecordRegistry.metadataProvider(ipId), address(metadataProvider));
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
        address licensorIpId = ipId;
        uint256 licenseId = licenseRegistry.mintLicense(policyId, licensorIpId, 1, bob);
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
            RECORD_HASH,
            RECORD_URL
        );


        /// Ensur registered IP post-conditions are met.
        assertEq(ipRecordRegistry.resolver(ipId2), address(resolver));
        assertEq(totalSupply + 1, ipRecordRegistry.totalSupply());
        assertTrue(ipRecordRegistry.isRegistered(ipId2));
        assertTrue(ipRecordRegistry.isRegistered(block.chainid, tokenAddress, tokenId2));
        assertEq(renderer.name(ipId2), RECORD_NAME);
        assertEq(renderer.hash(ipId2), RECORD_HASH);
        assertEq(renderer.owner(ipId2), bob);
    }

    /// @notice Checks that registration reverts when called by an invalid owner.
    function test_RegistrationModule_ARegisterDerivativeIP_Reverts_InvalidOwner() public {
        vm.expectRevert(Errors.RegistrationModule__InvalidOwner.selector);
        registrationModule.registerDerivativeIp(
            0,
            tokenAddress,
            tokenId,
            RECORD_NAME,
            RECORD_HASH,
            RECORD_URL
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
                address(resolver),
                address(metadataProvider)
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
        
        IParamVerifier[] memory parameters;
        bytes[] memory defaultValues;

        Licensing.FrameworkCreationParams memory fwParams = Licensing.FrameworkCreationParams({
            parameters: mintingVerifiers,
            defaultValues: mintingDefaultValues,
            licenseUrl: "https://example.com"
        });
        licenseRegistry.addLicenseFramework(fwParams);
        Licensing.Policy memory policy = Licensing.Policy({
            frameworkId: 1,
            commercialUse: true,
            derivatives: true,
            paramNames: new bytes32[](1),
            paramValues: new bytes[](1)
        });
        policy.paramNames[0] = verifier.name();
        policy.paramValues[0] = abi.encode(true);
        (uint256 polId) = licenseRegistry.addPolicy(policy);
        
        policyId = polId;
    }

}
