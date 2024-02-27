/* solhint-disable no-console */
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
import { IRoyaltyPolicyLAP } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP } from "contracts/lib/IP.sol";
import { PILFlavors } from "contracts/lib/PILFlavors.sol";
// solhint-disable-next-line max-line-length
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY, DISPUTE_MODULE_KEY, ROYALTY_MODULE_KEY, LICENSING_MODULE_KEY, TOKEN_WITHDRAWAL_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { LicensingModule } from "contracts/modules/licensing/LicensingModule.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty/RoyaltyModule.sol";
import { AncestorsVaultLAP } from "contracts/modules/royalty/policies/AncestorsVaultLAP.sol";
import { RoyaltyPolicyLAP } from "contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { DisputeModule } from "contracts/modules/dispute/DisputeModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute/policies/ArbitrationPolicySP.sol";
import { TokenWithdrawalModule } from "contracts/modules/external/TokenWithdrawalModule.sol";
// solhint-disable-next-line max-line-length
import { PILPolicyFrameworkManager, PILPolicy, RegisterPILPolicyParams } from "contracts/modules/licensing/PILPolicyFrameworkManager.sol";
import { MODULE_TYPE_HOOK } from "contracts/lib/modules/Module.sol";
import { IModule } from "contracts/interfaces/modules/base/IModule.sol";
import { IHookModule } from "contracts/interfaces/modules/base/IHookModule.sol";

// script
import { StringUtil } from "../../../script/foundry/utils/StringUtil.sol";
import { BroadcastManager } from "../../../script/foundry/utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "../../../script/foundry/utils/JsonDeploymentHandler.s.sol";

// test
import { MockERC20 } from "test/foundry/mocks/token/MockERC20.sol";
import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { MockTokenGatedHook } from "test/foundry/mocks/MockTokenGatedHook.sol";

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

    // Core Module
    RegistrationModule internal registrationModule;
    LicensingModule internal licensingModule;
    DisputeModule internal disputeModule;
    RoyaltyModule internal royaltyModule;

    // External Module
    TokenWithdrawalModule internal tokenWithdrawalModule;

    // Policy
    ArbitrationPolicySP internal arbitrationPolicySP;
    AncestorsVaultLAP internal ancestorsVaultImpl;
    RoyaltyPolicyLAP internal royaltyPolicyLAP;
    PILPolicyFrameworkManager internal pilPfm;

    // Misc.
    Governance internal governance;
    AccessController internal accessController;
    IPAssetRenderer internal ipAssetRenderer;
    IPResolver internal ipResolver;

    // Mocks
    MockERC20 internal erc20;
    MockERC721 internal erc721;

    // Hooks
    MockTokenGatedHook internal mockTokenGatedHook;

    mapping(uint256 tokenId => address ipAccountAddress) internal ipAcct;

    mapping(string policyName => uint256 policyId) internal policyIds;

    mapping(string frameworkName => address frameworkAddr) internal frameworkAddrs;

    // 0xSplits Liquid Split (Sepolia)
    address internal constant LIQUID_SPLIT_FACTORY = 0xF678Bae6091Ab6933425FE26Afc20Ee5F324c4aE;
    address internal constant LIQUID_SPLIT_MAIN = 0x57CBFA83f000a38C5b5881743E298819c503A559;

    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 MockToken
    uint256 internal constant MAX_ROYALTY_APPROVAL = 10000 ether;

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

        // Core Protocol Contracts

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
        ipAccountImpl = new IPAccountImpl(address(accessController));
        _postdeploy(contractKey, address(ipAccountImpl));

        contractKey = "ModuleRegistry";
        _predeploy(contractKey);
        moduleRegistry = new ModuleRegistry(address(governance));
        _postdeploy(contractKey, address(moduleRegistry));

        contractKey = "IPAccountRegistry";
        _predeploy(contractKey);
        ipAccountRegistry = new IPAccountRegistry(ERC6551_REGISTRY, address(ipAccountImpl));
        _postdeploy(contractKey, address(ipAccountRegistry));

        contractKey = "IPAssetRegistry";
        _predeploy(contractKey);
        ipAssetRegistry = new IPAssetRegistry(
            ERC6551_REGISTRY,
            address(ipAccountImpl),
            address(moduleRegistry),
            address(governance)
        );
        _postdeploy(contractKey, address(ipAssetRegistry));

        contractKey = "IPAssetRenderer";
        _predeploy(contractKey);
        ipAssetRenderer = new IPAssetRenderer(
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(royaltyModule)
        );
        _postdeploy(contractKey, address(ipAssetRenderer));

        contractKey = "RoyaltyModule";
        _predeploy(contractKey);
        royaltyModule = new RoyaltyModule(address(governance));
        _postdeploy(contractKey, address(royaltyModule));

        contractKey = "DisputeModule";
        _predeploy(contractKey);
        disputeModule = new DisputeModule(address(accessController), address(ipAssetRegistry), address(governance));
        _postdeploy(contractKey, address(disputeModule));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        licenseRegistry = new LicenseRegistry(
            address(governance),
            "https://github.com/storyprotocol/protocol-core/blob/main/assets/license-image.gif"
        );
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "LicensingModule";
        _predeploy(contractKey);
        licensingModule = new LicensingModule(
            address(accessController),
            address(ipAccountRegistry),
            address(royaltyModule),
            address(licenseRegistry),
            address(disputeModule)
        );
        _postdeploy(contractKey, address(licensingModule));

        contractKey = "IPResolver";
        _predeploy(contractKey);
        ipResolver = new IPResolver(address(accessController), address(ipAssetRegistry));
        _postdeploy(contractKey, address(ipResolver));

        contractKey = "RegistrationModule";
        _predeploy(contractKey);
        registrationModule = new RegistrationModule(
            address(ipAssetRegistry),
            address(licensingModule),
            address(ipResolver)
        );
        _postdeploy(contractKey, address(registrationModule));

        contractKey = "TokenWithdrawalModule";
        _predeploy(contractKey);
        tokenWithdrawalModule = new TokenWithdrawalModule(address(accessController), address(ipAccountRegistry));
        _postdeploy(contractKey, address(tokenWithdrawalModule));

        //
        // Story-specific Contracts
        //

        contractKey = "ArbitrationPolicySP";
        _predeploy(contractKey);
        arbitrationPolicySP = new ArbitrationPolicySP(
            address(disputeModule),
            address(erc20),
            ARBITRATION_PRICE,
            address(governance)
        );
        _postdeploy(contractKey, address(arbitrationPolicySP));

        contractKey = "RoyaltyPolicyLAP";
        _predeploy(contractKey);
        royaltyPolicyLAP = new RoyaltyPolicyLAP(
            address(royaltyModule),
            address(licensingModule),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN,
            address(governance)
        );
        _postdeploy(contractKey, address(royaltyPolicyLAP));

        contractKey = "AncestorsVaultLAP";
        _predeploy(contractKey);
        ancestorsVaultImpl = new AncestorsVaultLAP(address(royaltyPolicyLAP));
        _postdeploy(contractKey, address(ancestorsVaultImpl));

        _predeploy("PILPolicyFrameworkManager");
        pilPfm = new PILPolicyFrameworkManager(
            address(accessController),
            address(ipAccountRegistry),
            address(licensingModule),
            "pil",
            "https://github.com/storyprotocol/protocol-core/blob/main/PIL-Beta-2024-02.pdf"
        );
        _postdeploy("PILPolicyFrameworkManager", address(pilPfm));

        //
        // Mock Hooks
        //

        contractKey = "MockTokenGatedHook";
        _predeploy(contractKey);
        mockTokenGatedHook = new MockTokenGatedHook();
        _postdeploy(contractKey, address(mockTokenGatedHook));
    }

    function _configureDeployedProtocolContracts() private {
        _readDeployment();

        accessController = AccessController(_readAddress("main.AccessController"));
        moduleRegistry = ModuleRegistry(_readAddress("main.ModuleRegistry"));
        licenseRegistry = LicenseRegistry(_readAddress("main.LicenseRegistry"));
        ipAssetRegistry = IPAssetRegistry(_readAddress("main.IPAssetRegistry"));
        ipResolver = IPResolver(_readAddress("main.IPResolver"));
        registrationModule = RegistrationModule(_readAddress("main.RegistrationModule"));
        royaltyModule = RoyaltyModule(_readAddress("main.RoyaltyModule"));
        royaltyPolicyLAP = RoyaltyPolicyLAP(payable(_readAddress("main.royaltyPolicyLAP")));
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
        _configureRoyaltyRelated();
        _configureDisputeModule();
        _executeInteractions();
    }

    function _configureMisc() private {
        ipMetadataProvider = IPMetadataProvider(ipAssetRegistry.metadataProvider());
        _postdeploy("IPMetadataProvider", address(ipMetadataProvider));

        licenseRegistry.setDisputeModule(address(disputeModule));
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
        moduleRegistry.registerModule(ROYALTY_MODULE_KEY, address(royaltyModule));
        moduleRegistry.registerModule(TOKEN_WITHDRAWAL_MODULE_KEY, address(tokenWithdrawalModule));
    }

    function _configureRoyaltyRelated() private {
        royaltyModule.setLicensingModule(address(licensingModule));
        // whitelist
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLAP), true);
        royaltyModule.whitelistRoyaltyToken(address(erc20), true);

        royaltyPolicyLAP.setAncestorsVaultImplementation(address(ancestorsVaultImpl));
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
        for (uint256 i = 1; i <= 5; i++) {
            erc721.mintId(deployer, i);
        }
        erc721.mintId(deployer, 100);
        erc721.mintId(deployer, 101);
        erc721.mintId(deployer, 102);
        erc721.mintId(deployer, 103);
        erc721.mintId(deployer, 104);
        erc721.mintId(deployer, 105);
        erc20.mint(deployer, 100_000_000 ether);

        erc20.approve(address(arbitrationPolicySP), 1000 * ARBITRATION_PRICE); // 1000 * raising disputes
        // For license/royalty payment, on both minting license and royalty distribution
        erc20.approve(address(royaltyPolicyLAP), MAX_ROYALTY_APPROVAL);

        bytes memory emptyRoyaltyPolicyLAPInitParams = abi.encode(
            IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](0),
                targetRoyaltyAmount: new uint32[](0),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            })
        );

        licensingModule.registerPolicyFrameworkManager(address(pilPfm));
        frameworkAddrs["pil"] = address(pilPfm);

        /*///////////////////////////////////////////////////////////////
                                CREATE POLICIES
        ///////////////////////////////////////////////////////////////*/

        // Policy ID 1
        policyIds["social_remixing"] = pilPfm.registerPolicy(PILFlavors.nonCommercialSocialRemixing());

        // Policy ID 2
        policyIds["pil_com_deriv_expensive"] = pilPfm.registerPolicy(
            RegisterPILPolicyParams({
                transferable: true,
                royaltyPolicy: address(royaltyPolicyLAP),
                mintingFee: 1 ether,
                mintingFeeToken: address(erc20),
                policy: PILPolicy({
                    attribution: true,
                    commercialUse: true,
                    commercialAttribution: true,
                    commercializerChecker: address(mockTokenGatedHook),
                    commercializerCheckerData: abi.encode(address(erc721)), // use `erc721` as gated token
                    commercialRevShare: 100,
                    derivativesAllowed: true,
                    derivativesAttribution: false,
                    derivativesApproval: false,
                    derivativesReciprocal: true,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            })
        );

        // Policy ID 3
        policyIds["pil_noncom_deriv_reciprocal"] = pilPfm.registerPolicy(
            RegisterPILPolicyParams({
                transferable: false,
                royaltyPolicy: address(0), // no royalty, non-commercial
                mintingFee: 0, // no minting fee, non-commercial
                mintingFeeToken: address(0), // no minting fee token, non-commercial
                policy: PILPolicy({
                    attribution: true,
                    commercialUse: false,
                    commercialAttribution: false,
                    commercializerChecker: address(0),
                    commercializerCheckerData: "",
                    commercialRevShare: 0,
                    derivativesAllowed: true,
                    derivativesAttribution: true,
                    derivativesApproval: false,
                    derivativesReciprocal: true,
                    territories: new string[](0),
                    distributionChannels: new string[](0),
                    contentRestrictions: new string[](0)
                })
            })
        );

        /*///////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ///////////////////////////////////////////////////////////////*/

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

        // IPAccount2 (tokenId 2) with policy "pil_noncom_deriv_reciprocal"
        vm.label(getIpId(erc721, 2), "IPAccount2");
        ipAcct[2] = registrationModule.registerRootIp(
            policyIds["pil_noncom_deriv_reciprocal"],
            address(erc721),
            2,
            "IPAccount2",
            bytes32("some of the best description"),
            "https://example.com/test-ip"
        );

        accessController.setGlobalPermission(
            address(ipAssetRegistry),
            address(licensingModule),
            bytes4(0x9f69e70d),
            AccessPermission.ALLOW
        );

        accessController.setGlobalPermission(
            address(registrationModule),
            address(licenseRegistry),
            bytes4(0), // wildcard
            AccessPermission.ALLOW
        );

        accessController.setGlobalPermission(
            address(registrationModule),
            address(licenseRegistry),
            bytes4(0), // wildcard
            AccessPermission.ALLOW
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
                AccessPermission.ALLOW
            )
        );

        /*///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IPACCOUNTS
        ///////////////////////////////////////////////////////////////*/

        // Add "pil_com_deriv_expensive" policy to IPAccount1
        licensingModule.addPolicyToIp(ipAcct[1], policyIds["pil_com_deriv_expensive"]);

        /*///////////////////////////////////////////////////////////////
                    LINK IPACCOUNTS TO PARENTS USING LICENSES
        ///////////////////////////////////////////////////////////////*/

        // Mint 2 license of policy "pil_com_deriv_expensive" on IPAccount1
        // Register derivative IP for NFT tokenId 3
        {
            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_expensive"],
                ipAcct[1],
                2,
                deployer,
                emptyRoyaltyPolicyLAPInitParams
            );

            ipAcct[3] = getIpId(erc721, 3);
            vm.label(ipAcct[3], "IPAccount3");

            IRoyaltyPolicyLAP.InitParams memory params = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            params.targetAncestors[0] = ipAcct[1];
            params.targetRoyaltyAmount[0] = 100;

            registrationModule.registerDerivativeIp(
                licenseIds,
                address(erc721),
                3,
                "IPAccount3",
                bytes32("some of the best description"),
                "https://example.com/best-derivative-ip",
                abi.encode(params)
            );
        }

        // Mint 1 license of policy "pil_noncom_deriv_reciprocal" on IPAccount2
        // Register derivative IP for NFT tokenId 4
        {
            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = licensingModule.mintLicense(
                policyIds["pil_noncom_deriv_reciprocal"],
                ipAcct[2],
                1,
                deployer,
                emptyRoyaltyPolicyLAPInitParams
            );

            ipAcct[4] = getIpId(erc721, 4);
            vm.label(ipAcct[4], "IPAccount4");

            IRoyaltyPolicyLAP.InitParams memory params = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            params.targetAncestors[0] = ipAcct[2];
            params.targetRoyaltyAmount[0] = 100;

            ipAcct[4] = registrationModule.registerRootIp(
                0,
                address(erc721),
                4,
                "IPAccount4",
                bytes32("some of the best description"),
                "https://example.com/test-ip"
            );

            licensingModule.linkIpToParents(licenseIds, ipAcct[4], abi.encode(params));
        }

        // Multi-parent
        {
            ipAcct[5] = getIpId(erc721, 5);
            vm.label(ipAcct[5], "IPAccount5");

            uint256[] memory licenseIds = new uint256[](2);
            licenseIds[0] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_expensive"],
                ipAcct[1],
                1,
                deployer,
                emptyRoyaltyPolicyLAPInitParams
            );

            IRoyaltyPolicyLAP.InitParams memory paramsMintLicense = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            paramsMintLicense.targetAncestors[0] = ipAcct[1];
            paramsMintLicense.targetRoyaltyAmount[0] = 100;

            licenseIds[1] = licensingModule.mintLicense(
                policyIds["pil_com_deriv_expensive"],
                ipAcct[3], // is child of ipAcct[1]
                1,
                deployer,
                abi.encode(paramsMintLicense)
            );

            IRoyaltyPolicyLAP.InitParams memory paramsLinkParent = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](2),
                targetRoyaltyAmount: new uint32[](2),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](1),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](1)
            });
            paramsLinkParent.targetAncestors[0] = ipAcct[1]; // grandparent
            paramsLinkParent.targetAncestors[1] = ipAcct[3]; // parent
            paramsLinkParent.targetRoyaltyAmount[0] = 200; // 100 + 100
            paramsLinkParent.targetRoyaltyAmount[1] = 100;
            paramsLinkParent.parentAncestors2[0] = ipAcct[1];
            paramsLinkParent.parentAncestorsRoyalties2[0] = 100;

            ipAssetRegistry.register(
                licenseIds,
                abi.encode(paramsLinkParent),
                block.chainid,
                address(erc721),
                5,
                address(ipResolver),
                true,
                abi.encode(
                    IP.MetadataV1({
                        name: "name",
                        hash: "hash",
                        registrationDate: uint64(block.timestamp),
                        registrant: deployer,
                        uri: "uri"
                    })
                )
            );
        }

        /*///////////////////////////////////////////////////////////////
                            ROYALTY PAYMENT AND CLAIMS
        ///////////////////////////////////////////////////////////////*/

        // IPAccount1 and IPAccount3 have commercial policy, of which IPAccount5 has used to mint licenses.
        // Thus, any payment to IPAccount5 will get split to IPAccount1 and IPAccount3.

        // Deployer pays IPAccount5
        {
            royaltyModule.payRoyaltyOnBehalf(ipAcct[5], ipAcct[5], address(erc20), 1 ether);
        }

        // Distribute the accrued revenue from the 0xSplitWallet associated with IPAccount3 to
        // 0xSplits Main, which will get distributed to IPAccount3 AND its claimer based on revenue
        // sharing terms specified in the royalty policy.
        {
            (, , address ipAcct5_ancestorVault, , ) = royaltyPolicyLAP.royaltyData(ipAcct[5]);

            address[] memory accounts = new address[](2);
            // If you face InvalidSplit__AccountsOutOfOrder, shuffle the order of accounts (swap index 0 and 1)
            accounts[1] = ipAcct[5];
            accounts[0] = ipAcct5_ancestorVault;

            royaltyPolicyLAP.distributeIpPoolFunds(ipAcct[5], address(erc20), accounts, deployer);
        }

        // IPAccount1 claims its rNFTs and tokens, only done once since it's a direct chain
        {
            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = erc20;

            (, , address ancestorVault_ipAcct5, , ) = royaltyPolicyLAP.royaltyData(ipAcct[5]);

            // First, release the money from the IPAccount5's 0xSplitWallet (that just received money) to the main
            // 0xSplitMain that acts as a ledger for revenue distribution.
            // vm.expectEmit(LIQUID_SPLIT_MAIN);
            // TODO: check Withdrawal(699999999999999998) (Royalty stack is 300, or 30% [absolute] sent to ancestors)
            royaltyPolicyLAP.claimFromIpPool({ account: ipAcct[5], withdrawETH: 0, tokens: tokens });
            royaltyPolicyLAP.claimFromIpPool({ account: ancestorVault_ipAcct5, withdrawETH: 0, tokens: tokens });

            // Bob (owner of IPAccount1) calls the claim her portion of rNFTs and tokens. He can only call
            // `claimFromAncestorsVault` once. Afterwards, she will automatically receive money on revenue distribution.

            address[] memory ancestors = new address[](2);
            uint32[] memory ancestorsRoyalties = new uint32[](2);
            ancestors[0] = ipAcct[1]; // grandparent
            ancestors[1] = ipAcct[3]; // parent (claimer)
            ancestorsRoyalties[0] = 200;
            ancestorsRoyalties[1] = 100;

            // IPAccount1 wants to claim from IPAccount5
            royaltyPolicyLAP.claimFromAncestorsVault({
                ipId: ipAcct[5],
                claimerIpId: ipAcct[1],
                ancestors: ancestors,
                ancestorsRoyalties: ancestorsRoyalties,
                withdrawETH: false,
                tokens: tokens
            });
        }

        /*///////////////////////////////////////////////////////////////
                            DISPUTE MODULE INTERACTIONS
        ///////////////////////////////////////////////////////////////*/

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
            uint256 disputeId = disputeModule.raiseDispute(ipAcct[3], string("https://example.com"), "PLAGIARISM", "");

            disputeModule.cancelDispute(disputeId, bytes("Settled amicably"));
        }
    }

    function getIpId(MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        return ipAssetRegistry.ipAccount(block.chainid, address(mnft), tokenId);
    }
}
