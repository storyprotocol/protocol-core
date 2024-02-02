/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";
// contracts
import { AccessController } from "contracts/AccessController.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IP } from "contracts/lib/IP.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPAssetRegistry } from "contracts/registries/IPAssetRegistry.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { RoyaltyPolicyLS } from "contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { UMLPolicyFrameworkManager, UMLPolicy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// script
import { StringUtil } from "script/foundry/utils/StringUtil.sol";
import { BroadcastManager } from "script/foundry/utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "script/foundry/utils/JsonDeploymentHandler.s.sol";

// test
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

contract Main is Script, BroadcastManager, JsonDeploymentHandler {
    using StringUtil for uint256;
    using stdJson for string;

    Governance public governance;

    address public constant ERC6551_REGISTRY = address(0x000000006551c19487814612e58FE06813775758);
    AccessController public accessController;

    IPAssetRenderer public renderer;
    IPAssetRegistry public ipAssetRegistry;
    LicenseRegistry public licenseRegistry;
    ModuleRegistry public moduleRegistry;

    IPAccountImpl public implementation;
    MockERC721 public mockNft;

    IIPAccount public ipAccount;

    RegistrationModule public registrationModule;
    TaggingModule public taggingModule;
    RoyaltyModule public royaltyModule;
    RoyaltyPolicyLS public royaltyPolicyLS;
    DisputeModule public disputeModule;
    IPResolver public ipResolver;

    mapping(uint256 => uint256) internal nftIds;
    mapping(string => uint256) internal policyIds;
    mapping(string => address) internal frameworkIds;

    address internal constant LIQUID_SPLIT_FACTORY = address(0);
    address internal constant LIQUID_SPLIT_MAIN = address(0);

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

        contractKey = "Governance";
        _predeploy(contractKey);
        governance = new Governance(accessControlDeployer);
        _postdeploy(contractKey, address(governance));

        mockNft = new MockERC721("MockERC721");

        contractKey = "AccessController";
        _predeploy(contractKey);
        accessController = new AccessController(address(governance));
        _postdeploy(contractKey, address(accessController));

        contractKey = "IPAccountImpl";
        _predeploy(contractKey);
        implementation = new IPAccountImpl();
        _postdeploy(contractKey, address(implementation));

        contractKey = "ModuleRegistry";
        _predeploy(contractKey);
        moduleRegistry = new ModuleRegistry(address(governance));
        _postdeploy(contractKey, address(moduleRegistry));

        // TODO: deployment sequence
        contractKey = "IPAssetRegistry";
        _predeploy(contractKey);
        ipAssetRegistry = new IPAssetRegistry(address(accessController), ERC6551_REGISTRY, address(implementation));
        _postdeploy(contractKey, address(ipAssetRegistry));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        licenseRegistry = new LicenseRegistry(address(accessController), address(ipAssetRegistry));
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "IPResolver";
        _predeploy(contractKey);
        ipResolver = new IPResolver(address(accessController), address(ipAssetRegistry), address(licenseRegistry));
        _postdeploy(contractKey, address(ipResolver));

        contractKey = "RegistrationModule";
        _predeploy(contractKey);
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(ipResolver)
        );
        _postdeploy(contractKey, address(registrationModule));

        contractKey = "TaggingModule";
        _predeploy(contractKey);
        taggingModule = new TaggingModule();
        _postdeploy(contractKey, address(taggingModule));

        contractKey = "RoyaltyModule";
        _predeploy(contractKey);
        royaltyModule = new RoyaltyModule();
        _postdeploy(contractKey, address(royaltyModule));

        contractKey = "RoyaltyPolicyLS";
        _predeploy(contractKey);
        royaltyPolicyLS = new RoyaltyPolicyLS(
            address(royaltyModule),
            address(licenseRegistry),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN
        );
        _postdeploy(contractKey, address(royaltyPolicyLS));

        contractKey = "DisputeModule";
        _predeploy(contractKey);
        disputeModule = new DisputeModule();
        _postdeploy(contractKey, address(disputeModule));

        contractKey = "IPAssetRenderer";
        _predeploy(contractKey);
        renderer = new IPAssetRenderer(
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(taggingModule),
            address(royaltyModule)
        );
        _postdeploy(contractKey, address(renderer));

        // mockModule = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule");
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
        renderer = IPAssetRenderer(_readAddress("main.IPAssetRenderer"));

        _configureInteractions();
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }

    function _configureDeployment() private {
        _configureAccessController();
        _configureModuleRegistry();
        _configureInteractions();
        // _configureIPAccountRegistry();
        // _configureIPAssetRegistry();
    }

    function _configureAccessController() private {
        accessController.initialize(address(ipAssetRegistry), address(moduleRegistry));
    }

    function _configureModuleRegistry() private {
        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));
    }

    function _configureInteractions() private {
        nftIds[1] = mockNft.mint(deployer);
        nftIds[2] = mockNft.mint(deployer);
        nftIds[3] = mockNft.mint(deployer);
        nftIds[4] = mockNft.mint(deployer);

        registrationModule.registerRootIp(
            0,
            address(mockNft),
            nftIds[1],
            abi.encode(
                IP.MetadataV1({
                    name: "IPAccount1",
                    hash: bytes32("some of the best description"),
                    registrationDate: uint64(block.timestamp),
                    registrant: deployer,
                    uri: "https://example.com/test-ip"
                })
            )
        );
        registrationModule.registerRootIp(
            0,
            address(mockNft),
            nftIds[2],
            abi.encode(
                IP.MetadataV1({
                    name: "IPAccount2",
                    hash: bytes32("some of the best description"),
                    registrationDate: uint64(block.timestamp),
                    registrant: deployer,
                    uri: "https://example.com/test-ip"
                })
            )
        );

        accessController.setGlobalPermission(
            address(registrationModule),
            address(licenseRegistry),
            bytes4(0), // wildcard
            1 // AccessPermission.ALLOW
        );

        // wildcard allow
        IIPAccount(payable(getIpId(mockNft, nftIds[1]))).execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                getIpId(mockNft, 1),
                deployer,
                address(licenseRegistry),
                bytes4(0),
                1 // AccessPermission.ALLOW
            )
        );

        /*///////////////////////////////////////////////////////////////
                            CREATE LICENSE FRAMEWORKS
        ////////////////////////////////////////////////////////////////*/

        UMLPolicyFrameworkManager umlAllTrue = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(royaltyModule),
            "UML_ALL_TRUE",
            "https://very-nice-verifier-license.com/{id}.json"
        );
        licenseRegistry.registerPolicyFrameworkManager(address(umlAllTrue));
        UMLPolicyFrameworkManager umlMintPayment = new UMLPolicyFrameworkManager(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(royaltyModule),
            "UML_MINT_PAYMENT",
            "https://expensive-minting-license.com/{id}.json"
        );
        licenseRegistry.registerPolicyFrameworkManager(address(umlMintPayment));
        frameworkIds["all_true"] = address(umlAllTrue);
        frameworkIds["mint_payment"] = address(umlMintPayment);

        /*///////////////////////////////////////////////////////////////
                                CREATE POLICIES
        ////////////////////////////////////////////////////////////////*/

        policyIds["test_true"] = umlAllTrue.registerPolicy(
            UMLPolicy({
                attribution: true,
                transferable: true,
                commercialUse: true,
                commercialAttribution: true,
                commercializers: new string[](0),
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: true,
                derivativesReciprocal: true,
                derivativesRevShare: 0,
                territories: new string[](0),
                distributionChannels: new string[](0),
                royaltyPolicy: address(royaltyPolicyLS)
            })
        );

        policyIds["expensive_mint"] = umlAllTrue.registerPolicy(
            UMLPolicy({
                attribution: true,
                transferable: true,
                commercialUse: true,
                commercialAttribution: true,
                commercializers: new string[](0),
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: true,
                derivativesReciprocal: true,
                derivativesRevShare: 0,
                territories: new string[](0),
                distributionChannels: new string[](0),
                royaltyPolicy: address(royaltyPolicyLS)
            })
        );

        // /*///////////////////////////////////////////////////////////////
        //                     ADD POLICIES TO IPACCOUNTS
        // ////////////////////////////////////////////////////////////////*/

        licenseRegistry.addPolicyToIp(getIpId(mockNft, nftIds[1]), policyIds["test_true"]);
        licenseRegistry.addPolicyToIp(getIpId(mockNft, nftIds[2]), policyIds["expensive_mint"]);

        // /*///////////////////////////////////////////////////////////////
        //                     MINT LICENSES ON POLICIES
        // ////////////////////////////////////////////////////////////////*/

        // Mints 1 license for policy "test_true" on NFT id 1 IPAccount
        uint256 licenseId1 = licenseRegistry.mintLicense(
            policyIds["test_true"],
            getIpId(mockNft, nftIds[1]),
            2,
            deployer
        );
        uint256[] memory licenseIds = new uint256[](1);
        licenseIds[0] = licenseId1;

        registrationModule.registerDerivativeIp(
            licenseIds,
            address(mockNft),
            nftIds[3],
            "best derivative ip",
            bytes32("some of the best description"),
            "https://example.com/best-derivative-ip"
        );

        // /*///////////////////////////////////////////////////////////////
        //             LINK IPACCOUNTS TO PARENTS USING LICENSES
        // ////////////////////////////////////////////////////////////////*/
       
        licenseRegistry.linkIpToParents(licenseIds, getIpId(mockNft, nftIds[4]), deployer);
    }

    function getIpId(MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        return ipAssetRegistry.ipAccount(block.chainid, address(mnft), tokenId);
    }
}
