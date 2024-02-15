/* solhint-disable no-console 
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

// contracts
import { AccessController } from "contracts/AccessController.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { IP } from "contracts/lib/IP.sol";
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY, DISPUTE_MODULE_KEY, TAGGING_MODULE_KEY, ROYALTY_MODULE_KEY, LICENSING_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { LSClaimer } from "contracts/modules/royalty-module/policies/LSClaimer.sol";
import { RoyaltyPolicyLS } from "contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute-module/policies/ArbitrationPolicySP.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// script
import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";
import { BroadcastManager } from "../../../script/foundry/utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "../../../script/foundry/utils/JsonDeploymentHandler.s.sol";

// test
import { MockERC20 } from "test/foundry/mocks/MockERC20.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

contract Main is Script, BroadcastManager, JsonDeploymentHandler {
    using StringUtil for uint256;
    using stdJson for string;

    address internal ERC6551_REGISTRY = 0x000000006551c19487814612e58FE06813775758;
    IPAccountImpl internal ipAccountImpl;

    // Registry
    IPAccountRegistry internal ipAccountRegistry;
    IPMetadataProvider public ipMetadataProvider;
    IPAssetRegistry internal ipAssetRegistry;
    LicenseRegistry internal licenseRegistry;
    ModuleRegistry internal moduleRegistry;

    // Modules
    RegistrationModule internal registrationModule;
    LicensingModule internal licensingModule;
    DisputeModule internal disputeModule;
    ArbitrationPolicySP internal arbitrationPolicySP;
    RoyaltyModule internal royaltyModule;
    RoyaltyPolicyLS internal royaltyPolicyLS;
    TaggingModule internal taggingModule;

    // Misc.
    Governance internal governance;
    AccessController internal accessController;
    IPAssetRenderer internal ipAssetRenderer;
    IPResolver internal ipResolver;

    // Mocks
    MockERC20 internal erc20;
    MockERC721 internal erc721;

    mapping(uint256 tokenId => address ipAccountAddress) internal ipAcct;

    mapping(string policyName => uint256 policyId) internal policyIds;

    mapping(string frameworkName => address frameworkAddr) internal frameworkAddrs;

    // 0xSplits Liquid Split (Sepolia)
    address internal constant LIQUID_SPLIT_FACTORY = 0xF678Bae6091Ab6933425FE26Afc20Ee5F324c4aE;
    address internal constant LIQUID_SPLIT_MAIN = 0x57CBFA83f000a38C5b5881743E298819c503A559;

    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 MockToken
    uint256 internal constant ROYALTY_AMOUNT = 100 * 10 ** 6;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public {
        _beginBroadcast(); // BroadcastManager.s.sol

        bool configByMultisig = vm.envBool("DEPLOYMENT_CONFIG_BY_MULTISIG");
        console2.log("configByMultisig:", configByMultisig);

        if (configByMultisig) {
            _deployProtocolContracts(multisig);
        } else {
            _deployProtocolContracts(deployer);
            _configureDeployment();
        }
        // _configureDeployedProtocolContracts();

        _writeDeployment(); // write deployment json to deployments/deployment-{chainId}.json
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _deployProtocolContracts(address accessControlDeployer) private {
        require(
            LIQUID_SPLIT_FACTORY != address(0) && LIQUID_SPLIT_MAIN != address(0),
            "DeployMain: Liquid Split Addresses Not Set"
        );

        string memory contractKey;

        // Mock Assets (deploy first)

        contractKey = "MockERC20";
        _predeploy(contractKey);
        erc20 = new MockERC20();
        _postdeploy(contractKey, address(erc20));

        contractKey = "MockERC721";
        _predeploy(contractKey);
        erc721 = new MockERC721("MockERC721");
        _postdeploy(contractKey, address(erc721));

        // Protocol-related Contracts

        contractKey = "Governance";
        _predeploy(contractKey);
        governance = new Governance(accessControlDeployer);
        _postdeploy(contractKey, address(governance));

        contractKey = "AccessController";
        _predeploy(contractKey);
        accessController = new AccessController(address(governance));
        _postdeploy(contractKey, address(accessController));

        contractKey = "IPAccountImpl";
        _predeploy(contractKey);
        ipAccountImpl = new IPAccountImpl();
        _postdeploy(contractKey, address(ipAccountImpl));

        contractKey = "ModuleRegistry";
        _predeploy(contractKey);
        moduleRegistry = new ModuleRegistry(address(governance));
        _postdeploy(contractKey, address(moduleRegistry));

        contractKey = "IPAccountRegistry";
        _predeploy(contractKey);
        ipAccountRegistry = new IPAccountRegistry(
            ERC6551_REGISTRY,
            address(accessController),
            address(ipAccountImpl)
        );
        _postdeploy(contractKey, address(ipAccountRegistry));

        contractKey = "IPAssetRegistry";
        _predeploy(contractKey);
        ipAssetRegistry = new IPAssetRegistry(
            address(accessController),
            ERC6551_REGISTRY,
            address(ipAccountImpl),
            address(moduleRegistry),
            address(governance)
        );
        _postdeploy(contractKey, address(ipAssetRegistry));

        contractKey = "MetadataProviderV1";
        _predeploy(contractKey);
        _postdeploy(contractKey, ipAssetRegistry.metadataProvider());

        contractKey = "IPAssetRenderer";
        _predeploy(contractKey);
        ipAssetRenderer = new IPAssetRenderer(
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(taggingModule),
            address(royaltyModule)
        );
        _postdeploy(contractKey, address(ipAssetRenderer));

        contractKey = "RoyaltyModule";
        _predeploy(contractKey);
        royaltyModule = new RoyaltyModule(address(governance));
        _postdeploy(contractKey, address(royaltyModule));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        licenseRegistry = new LicenseRegistry();
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "LicensingModule";
        _predeploy(contractKey);
        licensingModule = new LicensingModule(
            address(accessController),
            address(ipAccountRegistry),
            address(royaltyModule),
            address(licenseRegistry)
        );
        _postdeploy(contractKey, address(licensingModule));

        contractKey = "TaggingModule";
        _predeploy(contractKey);
        taggingModule = new TaggingModule();
        _postdeploy(contractKey, address(taggingModule));

        contractKey = "IPResolver";
        _predeploy(contractKey);
        ipResolver = new IPResolver(address(accessController), address(ipAssetRegistry));
        _postdeploy(contractKey, address(ipResolver));

        contractKey = "RegistrationModule";
        _predeploy(contractKey);
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipAssetRegistry),
            address(licensingModule),
            address(ipResolver)
        );
        _postdeploy(contractKey, address(registrationModule));

        contractKey = "DisputeModule";
        _predeploy(contractKey);
        disputeModule = new DisputeModule(
            address(accessController),
            address(ipAssetRegistry),
            address(governance)
        );
        _postdeploy(contractKey, address(disputeModule));

        arbitrationPolicySP = new ArbitrationPolicySP(
            address(disputeModule),
            address(erc20),
            ARBITRATION_PRICE,
            address(governance)
        );

        contractKey = "RoyaltyPolicyLS";
        _predeploy(contractKey);
        royaltyPolicyLS = new RoyaltyPolicyLS(
            address(royaltyModule),
            address(licensingModule),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN
        );
        _postdeploy(contractKey, address(royaltyPolicyLS));
    }

    function _configureDeployedProtocolContracts() private {
        _readDeployment();

        accessController = AccessController(_readAddress("main.AccessController"));
        moduleRegistry = ModuleRegistry(_readAddress("main.ModuleRegistry"));
        licenseRegistry = LicenseRegistry(_readAddress("main.LicenseRegistry"));
        ipAssetRegistry = IPAssetRegistry(_readAddress("main.IPAssetRegistry"));
        ipResolver = IPResolver(_readAddress("main.IPResolver"));
        registrationModule = RegistrationModule(_readAddress("main.RegistrationModule"));
        taggingModule = TaggingModule(_readAddress("main.TaggingModule"));
        royaltyModule = RoyaltyModule(_readAddress("main.RoyaltyModule"));
        royaltyPolicyLS = RoyaltyPolicyLS(_readAddress("main.RoyaltyPolicyLS"));
        disputeModule = DisputeModule(_readAddress("main.DisputeModule"));
        ipAssetRenderer = IPAssetRenderer(_readAddress("main.IPAssetRenderer"));
        ipMetadataProvider = IPMetadataProvider(_readAddress("main.IPMetadataProvider"));

        _executeInteractions();
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }

    function _configureDeployment() private {
        _configureMisc();
        _configureAccessController();
        _configureModuleRegistry();
        _configureRoyaltyPolicy();
        _configureDisputeModule();
        _executeInteractions();
    }

    function _configureMisc() private {
        ipMetadataProvider = IPMetadataProvider(ipAssetRegistry.metadataProvider());
        _postdeploy("IPMetadataProvider", address(ipMetadataProvider));

        licenseRegistry.setLicensingModule(address(licensingModule));
        ipAssetRegistry.setRegistrationModule(address(registrationModule));
    }

    function _configureAccessController() private {
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));

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

    function _configureModuleRegistry() private {
        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));
        moduleRegistry.registerModule(DISPUTE_MODULE_KEY, address(disputeModule));
        moduleRegistry.registerModule(LICENSING_MODULE_KEY, address(licensingModule));
        moduleRegistry.registerModule(TAGGING_MODULE_KEY, address(taggingModule));
        moduleRegistry.registerModule(ROYALTY_MODULE_KEY, address(royaltyModule));
    }

    function _configureRoyaltyPolicy() private {
        royaltyModule.setLicensingModule(address(licensingModule));
        // whitelist
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);
    }

    function _configureDisputeModule() private {
        // whitelist
        disputeModule.whitelistDisputeTag("PLAGIARISM", true);
        disputeModule.whitelistArbitrationPolicy(address(arbitrationPolicySP), true);
        address arbitrationRelayer = deployer;
        disputeModule.whitelistArbitrationRelayer(address(arbitrationPolicySP), arbitrationRelayer, true);

        disputeModule.setBaseArbitrationPolicy(address(arbitrationPolicySP));
    }

    function _executeInteractions() private {
        erc721.mintId(deployer, 1);
        erc721.mintId(deployer, 2);
        erc721.mintId(deployer, 3);
        erc721.mintId(deployer, 4);
        erc20.mint(deployer, 100_000 * 10 ** 6);

        erc20.approve(address(arbitrationPolicySP), 10 * ARBITRATION_PRICE); // 10 * raising disputes
        erc20.approve(address(royaltyPolicyLS), ROYALTY_AMOUNT);

        uint32 minRevShareIpAcct1 = 300; // 30%

        ///////////////////////////////////////////////////////////////
                        CREATE POLICY FRAMEWORK MANAGERS
        ////////////////////////////////////////////////////////////////

        UMLPolicyFrameworkManager umlPfm = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "uml",
            "https://uml-license.com/{id}.json"
        );
        licensingModule.registerPolicyFrameworkManager(address(umlPfm));
        frameworkAddrs["uml"] = address(umlPfm);

        ///////////////////////////////////////////////////////////////
                                CREATE POLICIES
        ////////////////////////////////////////////////////////////////

        policyIds["uml_com_deriv_expensive"] = umlPfm.registerPolicy(
            UMLPolicy({
                attribution: true,
                transferable: true,
                commercialUse: true,
                commercialAttribution: true,
                commercializers: new string[](0),
                commercialRevShare: 100,
                derivativesAllowed: true,
                derivativesAttribution: false,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativesRevShare: minRevShareIpAcct1,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0),
                royaltyPolicy: address(royaltyPolicyLS)
            })
        );

        policyIds["uml_noncom_deriv_reciprocal"] = umlPfm.registerPolicy(
            UMLPolicy({
                attribution: true,
                transferable: false,
                commercialUse: false,
                commercialAttribution: false,
                commercializers: new string[](0),
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativesRevShare: 0,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0),
                royaltyPolicy: address(0) // non-commercial => no royalty policy
            })
        );

        ///////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ////////////////////////////////////////////////////////////////

        // IPAccount1 (tokenId 1) with no initial policy
        vm.label(getIpId(erc721, 1), "IPAccount1");
        ipAcct[1] = registrationModule.registerRootIp(
            0,
            address(erc721),
            1,
            "IPAccount1",
            bytes32("some content hash"),
            "https://example.com/test-ip"
        );
        disputeModule.setArbitrationPolicy(ipAcct[1], address(arbitrationPolicySP));

        // IPAccount2 (tokenId 2) with policy "uml_noncom_deriv_reciprocal"
        vm.label(getIpId(erc721, 2), "IPAccount2");
        ipAcct[2] = registrationModule.registerRootIp(
            policyIds["uml_noncom_deriv_reciprocal"],
            address(erc721),
            2,
            "IPAccount2",
            bytes32("some of the best description"),
            "https://example.com/test-ip"
        );

        accessController.setGlobalPermission(
            address(ipAssetRegistry),
            address(licensingModule),
            bytes4(0),
            1
        );

        accessController.setGlobalPermission(
            address(registrationModule),
            address(licenseRegistry),
            bytes4(0), // wildcard
            1 // AccessPermission.ALLOW
        );

        // wildcard allow
        IIPAccount(payable(ipAcct[1])).execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                ipAcct[1],
                deployer,
                address(licenseRegistry),
                bytes4(0),
                1 // AccessPermission.ALLOW
            )
        );

        ///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IPACCOUNTS
        ////////////////////////////////////////////////////////////////

        // Add "uml_com_deriv_expensive" policy to IPAccount1
        licensingModule.addPolicyToIp(ipAcct[1], policyIds["uml_com_deriv_expensive"]);

        // ROYALTY_MODULE.setRoyaltyPolicy(ipId, newRoyaltyPolicy, new address[](0), abi.encode(minRoyalty));

        ///////////////////////////////////////////////////////////////
                            MINT LICENSES ON POLICIES
        ////////////////////////////////////////////////////////////////

        // Mint 2 license of policy "uml_com_deriv_expensive" on IPAccount1
        // Register derivative IP for NFT tokenId 3
        {
            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = licensingModule.mintLicense(policyIds["uml_com_deriv_expensive"], ipAcct[1], 2, deployer);

            ipAcct[3] = getIpId(erc721, 3);
            vm.label(ipAcct[3], "IPAccount3");

            registrationModule.registerDerivativeIp(
                licenseIds,
                address(erc721),
                3,
                "IPAccount3",
                bytes32("some of the best description"),
                "https://example.com/best-derivative-ip",
                0
            );
        }

        ///////////////////////////////////////////////////////////////
                    LINK IPACCOUNTS TO PARENTS USING LICENSES
        ////////////////////////////////////////////////////////////////

        // Mint 1 license of policy "uml_noncom_deriv_reciprocal" on IPAccount2
        // Register derivative IP for NFT tokenId 4
        {
            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = licensingModule.mintLicense(
                policyIds["uml_noncom_deriv_reciprocal"],
                ipAcct[2],
                1,
                deployer
            );

            ipAcct[4] = getIpId(erc721, 4);
            vm.label(ipAcct[4], "IPAccount4");

            ipAcct[4] = registrationModule.registerRootIp(
                0,
                address(erc721),
                4,
                "IPAccount4",
                bytes32("some of the best description"),
                "https://example.com/test-ip"
            );

            licensingModule.linkIpToParents(licenseIds, ipAcct[4], 0);
        }

        ///////////////////////////////////////////////////////////////
                            ROYALTY PAYMENT AND CLAIMS
        ////////////////////////////////////////////////////////////////

        // IPAccount1 has commercial policy, of which IPAccount3 has used to mint a license.
        // Thus, any payment to IPAccount3 will get split to IPAccount1.

        // Deployer pays to IPAccount3 (for test purposes).
        {
            royaltyModule.payRoyaltyOnBehalf(ipAcct[3], deployer, address(erc20), ROYALTY_AMOUNT);
        }

        // Distribute the accrued revenue from the 0xSplitWallet associated with IPAccount3 to
        // 0xSplits Main, which will get distributed to IPAccount3 AND its claimer based on revenue
        // sharing terms specified in the royalty policy.
        {
            (, address ipAcct3_claimer, , ) = royaltyPolicyLS.royaltyData(ipAcct[3]);

            address[] memory accounts = new address[](2);
            // order matters, otherwise error: InvalidSplit__AccountsOutOfOrder
            accounts[0] = ipAcct3_claimer;
            accounts[1] = ipAcct[3];

            royaltyPolicyLS.distributeFunds(ipAcct[3], address(erc20), accounts, address(0));
        }

        // IPAccount1 claims its rNFTs and tokens, only done once since it's a direct chain
        {
            (, address ipAcct3_claimer, , ) = royaltyPolicyLS.royaltyData(ipAcct[3]);

            address[] memory chain_ipAcct1_to_ipAcct3 = new address[](2);
            chain_ipAcct1_to_ipAcct3[0] = ipAcct[1];
            chain_ipAcct1_to_ipAcct3[1] = ipAcct[3];

            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = erc20;

            // Alice calls on behalf of Dan's claimer to send money from the Split Main to Dan's claimer,
            // since the revenue payment was made to Dan's Split Wallet, which got distributed to the claimer.

            // Dan is paying 65% of 1000 erc20 royalty to parents (stored in Dan's Claimer).
            // The other 35% of 1000 erc20 royalty goes directly to Dan's IPAccount.
            royaltyPolicyLS.claimRoyalties({ _account: ipAcct3_claimer, _withdrawETH: 0, _tokens: tokens });

            // Alice calls the claim her portion of rNFTs and tokens. She can only call `claim` once.
            // Afterwards, she will automatically receive money on revenue distribution.

            LSClaimer(ipAcct3_claimer).claim({
                _path: chain_ipAcct1_to_ipAcct3,
                _claimerIpId: ipAcct[1],
                _withdrawETH: false,
                _tokens: tokens
            });
        }

        ///////////////////////////////////////////////////////////////
                            TAGGING MODULE INTERACTIONS
        ////////////////////////////////////////////////////////////////

        taggingModule.setTag("premium", ipAcct[1]);
        taggingModule.setTag("cheap", ipAcct[1]);
        taggingModule.removeTag("cheap", ipAcct[1]);
        taggingModule.setTag("luxury", ipAcct[1]);

        ///////////////////////////////////////////////////////////////
                            DISPUTE MODULE INTERACTIONS
        ////////////////////////////////////////////////////////////////

        // Say, IPAccount4 is accused of plagiarism by IPAccount2
        // Then, a judge (deployer in this example) settles as true.
        // Then, the dispute is resolved.
        {
            uint256 disptueId = disputeModule.raiseDispute(
                ipAcct[4],
                string("evidence-url.com"), // TODO: https://dispute-evidence-url.com => string too long
                "PLAGIARISM",
                ""
            );

            disputeModule.setDisputeJudgement(disptueId, true, "");

            disputeModule.resolveDispute(disptueId);
        }

        // Say, IPAccount3 is accused of plagiarism by IPAccount1
        // But, IPAccount1 later cancels the dispute
        {
            uint256 disputeId = disputeModule.raiseDispute(
                ipAcct[3],
                string("https://example.com"),
                "PLAGIARISM",
                ""
            );

            disputeModule.cancelDispute(disputeId, bytes("Settled amicably"));
        }
    }

    function getIpId(MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        return ipAssetRegistry.ipAccount(block.chainid, address(mnft), tokenId);
    }
}
 */