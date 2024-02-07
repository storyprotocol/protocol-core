// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

// external
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test } from "forge-std/Test.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";
import { IERC6551Registry } from "lib/reference/src/interfaces/IERC6551Registry.sol";
import { ERC6551AccountLib } from "lib/reference/src/lib/ERC6551AccountLib.sol";

// contracts
import { AccessController } from "contracts/AccessController.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IRegistrationModule } from "contracts/interfaces/modules/IRegistrationModule.sol";
import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY, DISPUTE_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { LSClaimer } from "contracts/modules/royalty-module/policies/LSClaimer.sol";
import { RoyaltyPolicyLS } from "contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute-module/policies/ArbitrationPolicySP.sol";

// test
import { MockERC20 } from "test/foundry/mocks/MockERC20.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { MockModule } from "test/foundry/mocks/MockModule.sol";
import { MockUSDC } from "test/foundry/mocks/MockUSDC.sol";
import { MockRoyaltyPolicyLS } from "test/foundry/mocks/MockRoyaltyPolicyLS.sol";
import { Users, UsersLib } from "test/foundry/utils/Users.sol";


struct MockERC721s {
    MockERC721 ape;
    MockERC721 cat;
    MockERC721 dog;
}

import "forge-std/console2.sol";

contract DeployHelper is Test {
    ERC6551Registry internal erc6551Registry;
    IPAccountImpl internal ipAccountImpl;

    // Registry
    IPAccountRegistry internal ipAccountRegistry;
    IPMetadataProvider internal ipMetadataProvider;
    IPAssetRegistry internal ipAssetRegistry;
    LicenseRegistry internal licenseRegistry;
    ModuleRegistry internal moduleRegistry;

    // Modules
    RegistrationModule internal registrationModule;
    DisputeModule internal disputeModule;
    ArbitrationPolicySP internal arbitrationPolicySP;
    ArbitrationPolicySP internal arbitrationPolicySP2;
    RoyaltyModule internal royaltyModule;
    RoyaltyPolicyLS internal royaltyPolicyLS;
    LSClaimer internal lsClaimer;
    TaggingModule internal taggingModule;
    LicensingModule internal licensingModule;

    // Misc.
    Governance internal governance;
    AccessController internal accessController;
    IPAssetRenderer internal ipAssetRenderer;
    IPResolver internal ipResolver;

    // Mocks
    MockERC20 internal erc20;
    MockERC721s internal erc721;
    MockUSDC internal USDC;
    MockRoyaltyPolicyLS internal mockRoyaltyPolicyLS;

    // Helpers
    Users internal u;

    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6;

    // 0xSplits Liquid Split (Sepolia)
    address internal constant LIQUID_SPLIT_FACTORY = 0xF678Bae6091Ab6933425FE26Afc20Ee5F324c4aE;
    address internal constant LIQUID_SPLIT_MAIN = 0x57CBFA83f000a38C5b5881743E298819c503A559;

    function deploy() public virtual {
        u = UsersLib.createMockUsers(vm);

        _deployMockAssets(); // deploy mock assets first
        _deployContracts();
        _configDeployedContracts();
        _mintMockAssets();
        _configAccessControl();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                DEPLOYMENT LOGICS
    //////////////////////////////////////////////////////////////////////////*/

    function _deployContracts() internal {
        governance = new Governance(u.admin);
        
        accessController = new AccessController(address(governance));
        erc6551Registry = new ERC6551Registry();
        ipAccountImpl = new IPAccountImpl();

        moduleRegistry = new ModuleRegistry(address(governance));
        ipAccountRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(ipAccountImpl)
        );
        royaltyModule = new RoyaltyModule(address(governance));
        ipAssetRegistry = new IPAssetRegistry(
            address(accessController),
            address(erc6551Registry),
            address(ipAccountImpl)
        );
        licenseRegistry = new LicenseRegistry();
        licensingModule = new LicensingModule(
            address(accessController),
            address(ipAssetRegistry),
            address(royaltyModule),
            address(licenseRegistry)
        );
        licenseRegistry.setLicensingModule(address(licensingModule));
        ipMetadataProvider = new IPMetadataProvider(address(moduleRegistry));
        ipResolver = new IPResolver(address(accessController), address(ipAssetRegistry));
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(licensingModule),
            address(ipResolver)
        );
        taggingModule = new TaggingModule();
        disputeModule = new DisputeModule(
            address(accessController),
            address(ipAssetRegistry),
            address(governance)
        );
        ipAssetRenderer = new IPAssetRenderer(
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(taggingModule),
            address(royaltyModule)
        );

        arbitrationPolicySP = new ArbitrationPolicySP(
            address(disputeModule),
            address(USDC),
            ARBITRATION_PRICE,
            address(governance)
        );
        arbitrationPolicySP2 = new ArbitrationPolicySP(
            address(disputeModule),
            address(USDC),
            ARBITRATION_PRICE,
            address(governance)
        );

        royaltyPolicyLS = new RoyaltyPolicyLS(
            address(royaltyModule),
            address(licensingModule),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN
        );

        mockRoyaltyPolicyLS = new MockRoyaltyPolicyLS(address(royaltyModule));
    }

    function _configDeployedContracts() internal {
        vm.startPrank(u.admin);
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
        royaltyModule.setLicensingModule(address(licensingModule));

        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));
        moduleRegistry.registerModule("LICENSING_MODULE", address(licensingModule));
        moduleRegistry.registerModule(DISPUTE_MODULE_KEY, address(disputeModule));

        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);
        royaltyModule.whitelistRoyaltyPolicy(address(mockRoyaltyPolicyLS), true);
        royaltyModule.whitelistRoyaltyToken(address(USDC), true);
        vm.stopPrank();
    }

    function _deployMockAssets() internal {
        erc20 = new MockERC20();
        erc721 = MockERC721s({ ape: new MockERC721("Ape"), cat: new MockERC721("Cat"), dog: new MockERC721("Dog") });
        USDC = new MockUSDC();
    }

    function _mintMockAssets() internal {
        erc20.mint(u.alice, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.bob, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.carl, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.dan, 1000 * 10 ** erc20.decimals());
        USDC.mint(u.alice, 100_000 * 10 ** USDC.decimals());
        USDC.mint(u.bob, 100_000 * 10 ** USDC.decimals());
        USDC.mint(u.carl, 100_000 * 10 ** USDC.decimals());
        USDC.mint(u.dan, 100_000 * 10 ** USDC.decimals());
        // skip minting NFTs
    }

    function _configAccessControl() internal {
        // Set global perm to allow Registration Module to call License Registry on all IPAccounts
        vm.startPrank(u.admin); // admin of governance

        accessController.setGlobalPermission(
            address(registrationModule),
            address(licensingModule),
            bytes4(licensingModule.linkIpToParents.selector),
            1 // AccessPermission.ALLOW
        );

        accessController.setGlobalPermission(
            address(registrationModule),
            address(licensingModule),
            bytes4(licensingModule.addPolicyToIp.selector),
            1 // AccessPermission.ALLOW
        );

        vm.stopPrank();
    }
}
