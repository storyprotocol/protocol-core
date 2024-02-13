/* solhint-disable no-console */
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { console2 } from "forge-std/console2.sol"; // console to indicate mock deployment calls.
import { Test } from "forge-std/Test.sol";

// contracts
// solhint-disable-next-line max-line-length
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY, DISPUTE_MODULE_KEY, TAGGING_MODULE_KEY, ROYALTY_MODULE_KEY, LICENSING_MODULE_KEY } from "../../../contracts/lib/modules/Module.sol";
import { AccessPermission } from "../../../contracts/lib/AccessPermission.sol";

// test
import { DeployHelper } from "./DeployHelper.sol";
import { LicensingHelper } from "./LicensingHelper.sol";
import { MockERC20 } from "../mocks/token/MockERC20.sol";
import { MockERC721 } from "../mocks/token/MockERC721.sol";
import { Users, UsersLib } from "./Users.sol";

/// @title Base Test Contract
/// @notice This contract provides a set of protocol-related testing utilities
///         that may be extended by testing contracts.
contract BaseTest is Test, DeployHelper, LicensingHelper {
    /// @dev Users struct to abstract away user management when testing
    Users internal u;

    /// @dev Aliases for users
    address internal admin;
    address internal alice;
    address internal bob;
    address internal carl;
    address internal dan;
    address internal don; // don is dan, dan is don

    /// @dev Aliases for mock assets.
    /// NOTE: Must call `postDeploymentSetup` after `deployConditionally` to set these.
    MockERC20 internal mockToken; // alias for erc20
    MockERC20 internal USDC; // alias for mockToken/erc20
    MockERC721 internal mockNFT; // alias for erc721.ape

    /// @notice Sets up the base test contract.
    function setUp() public virtual {
        u = UsersLib.createMockUsers(vm);
        setGovernanceAdmin(u.admin);

        admin = u.admin;
        alice = u.alice;
        bob = u.bob;
        carl = u.carl;
        dan = u.dan;
        don = dan;

        vm.label(LIQUID_SPLIT_FACTORY, "LIQUID_SPLIT_FACTORY");
        vm.label(LIQUID_SPLIT_MAIN, "LIQUID_SPLIT_MAIN");
    }

    function postDeploymentSetup() public {
        if (postDeployConditions.accessController_init) initAccessController();
        if (postDeployConditions.moduleRegistry_registerModules) registerModules();
        if (postDeployConditions.royaltyModule_configure) configureRoyaltyModule();
        if (postDeployConditions.disputeModule_configure) configureDisputeModule();
        if (deployConditions.registry.licenseRegistry) {
            configureLicenseRegistry();
        }
        if (deployConditions.module.registrationModule) {
            // TODO: also conditionally check on `deployConditions.registry.ipAssetRegistry`
            configureIPAssetRegistry();
        }

        bool isMockRoyaltyPolicyLS = address(royaltyPolicyLS) == address(0) &&
            address(mockRoyaltyPolicyLS) != address(0);

        // Initialize licensing helper
        // TODO: conditionally init and use LicensingHelper.
        initLicensingHelper(
            getAccessController(),
            address(ipAccountRegistry),
            getLicensingModule(),
            getRoyaltyModule(),
            isMockRoyaltyPolicyLS ? address(mockRoyaltyPolicyLS) : address(royaltyPolicyLS)
        );

        // Set aliases
        mockToken = erc20;
        USDC = erc20;
        mockNFT = erc721.ape;
    }

    function dealMockAssets() public {
        erc20.mint(u.alice, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.bob, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.carl, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.dan, 1000 * 10 ** erc20.decimals());
    }

    /// @dev Initialize the access controller to abstract away access controller initialization when testing
    function initAccessController() public {
        console2.log("BaseTest PostDeploymentSetup: Init Access Controller");
        require(address(ipAccountRegistry) != address(0), "ipAccountRegistry not set");
        vm.startPrank(u.admin);
        accessController.initialize(address(ipAccountRegistry), getModuleRegistry());

        // If REAL Registration Module and Licensing Module are deployed, set global permissions
        if (deployConditions.module.registrationModule && deployConditions.module.licensingModule) {
            accessController.setGlobalPermission(
                address(registrationModule),
                address(licensingModule),
                bytes4(licensingModule.linkIpToParents.selector),
                AccessPermission.ALLOW
            );

            accessController.setGlobalPermission(
                address(registrationModule),
                address(licensingModule),
                bytes4(licensingModule.addPolicyToIp.selector),
                AccessPermission.ALLOW
            );
        }

        vm.stopPrank();
    }

    /// @dev Register modules to abstract away module registration when testing
    function registerModules() public {
        console2.log("BaseTest PostDeploymentSetup: Register Modules");
        vm.startPrank(u.admin);
        if (address(registrationModule) != address(0)) {
            moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        }
        if (address(ipResolver) != address(0)) {
            moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));
        }
        if (address(disputeModule) != address(0)) {
            moduleRegistry.registerModule(DISPUTE_MODULE_KEY, address(disputeModule));
        }
        if (address(licensingModule) != address(0)) {
            moduleRegistry.registerModule(LICENSING_MODULE_KEY, address(licensingModule));
        }
        if (address(taggingModule) != address(0)) {
            moduleRegistry.registerModule(TAGGING_MODULE_KEY, address(taggingModule));
        }
        if (address(royaltyModule) != address(0)) {
            moduleRegistry.registerModule(ROYALTY_MODULE_KEY, address(royaltyModule));
        }
        vm.stopPrank();
    }

    /// @dev Pre-set configs to abstract away configs when testing with royalty module
    function configureRoyaltyModule() public {
        console2.log("BaseTest PostDeploymentSetup: Configure Royalty Module");
        require(address(royaltyModule) != address(0), "royaltyModule not set");

        vm.startPrank(u.admin);
        royaltyModule.setLicensingModule(getLicensingModule());
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);
        if (address(royaltyPolicyLS) != address(0)) {
            royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);
        }
        vm.stopPrank();
    }

    /// @dev Pre-set configs to abstract away configs when testing with dispute module
    function configureDisputeModule() public {
        console2.log("BaseTest PostDeploymentSetup: Configure Dispute Module");
        require(address(disputeModule) != address(0), "disputeModule not set");

        vm.startPrank(u.admin);
        disputeModule.whitelistDisputeTag("PLAGIARISM", true);
        if (address(arbitrationPolicySP) != address(0)) {
            disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);
            disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), u.admin, true);
            disputeModule.setBaseArbitrationPolicy(address(arbitrationPolicySP));
        }
        vm.stopPrank();
    }

    function configureLicenseRegistry() public {
        console2.log("BaseTest PostDeploymentSetup: Configure License Registry");
        require(address(licenseRegistry) != address(0), "licenseRegistry not set");

        vm.startPrank(u.admin);
        licenseRegistry.setLicensingModule(getLicensingModule());
        vm.stopPrank();
    }

    function configureIPAssetRegistry() public {
        console2.log("BaseTest PostDeploymentSetup: Configure IP Asset Registry");
        require(address(ipAssetRegistry) != address(0), "ipAssetRegistry not set");
        require(address(registrationModule) != address(0), "registrationModule not set");

        vm.startPrank(u.admin);
        ipAssetRegistry.setRegistrationModule(address(registrationModule));
        vm.stopPrank();
    }

    function _getIpId(MockERC721 mnft, uint256 tokenId) internal view returns (address ipId) {
        return _getIpId(address(mnft), tokenId);
    }

    function _getIpId(address mnft, uint256 tokenId) internal view returns (address ipId) {
        return ipAccountRegistry.ipAccount(block.chainid, mnft, tokenId);
    }
}
