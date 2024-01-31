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
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
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
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { Governance } from "contracts/governance/Governance.sol";
import { UMLPolicy } from "contracts/interfaces/licensing/IUMLPolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// test
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

// script
import { StringUtil } from "script/foundry/utils/StringUtil.sol";
import { BroadcastManager } from "script/foundry/utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "script/foundry/utils/JsonDeploymentHandler.s.sol";

contract Main is Script, BroadcastManager, JsonDeploymentHandler {
    using StringUtil for uint256;
    using stdJson for string;

    Governance public governance;

    address public constant ERC6551_REGISTRY = address(0x000000006551c19487814612e58FE06813775758);
    AccessController public accessController;

    IPAssetRenderer public renderer;
    IPMetadataProvider public metadataProvider;
    IPAccountRegistry public ipAccountRegistry;
    IPAssetRegistry public ipAssetRegistry;
    LicenseRegistry public licenseRegistry;
    ModuleRegistry public moduleRegistry;

    IPAccountImpl public implementation;
    MockERC721 public mockNft;

    IIPAccount public ipAccount;
    //    ERC6551Registry public erc6551Registry;

    RegistrationModule public registrationModule;
    TaggingModule public taggingModule;
    RoyaltyModule public royaltyModule;
    DisputeModule public disputeModule;
    IPResolver public ipResolver;

    mapping(uint256 => uint256) internal nftIds;
    mapping(string => uint256) internal policyIds;
    mapping(string => uint256) internal frameworkIds;

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

        _writeDeployment(); // write deployment json to deployments/deployment-{chainId}.json
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _deployProtocolContracts(address accessControldeployer) private {
        string memory contractKey;

        contractKey = "Governance";
        _predeploy(contractKey);
        governance = new Governance(accessControldeployer);
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

        contractKey = "IPAccountRegistry";
        _predeploy(contractKey);
        ipAccountRegistry = new IPAccountRegistry(ERC6551_REGISTRY, address(accessController), address(implementation));
        _postdeploy(contractKey, address(ipAccountRegistry));

        // TODO: deployment sequence
        contractKey = "IPAssetRegistry";
        _predeploy(contractKey);
        ipAssetRegistry = new IPAssetRegistry(address(accessController), ERC6551_REGISTRY, address(implementation), address(metadataProvider));
        _postdeploy(contractKey, address(ipAssetRegistry));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        licenseRegistry = new LicenseRegistry(address(accessController), address(ipAccountRegistry));
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "IPResolver";
        _predeploy(contractKey);
        ipResolver = new IPResolver(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry)
        );
        _postdeploy(contractKey, address(ipResolver));

        contractKey = "MetadataProvider";
        _predeploy(contractKey);
        metadataProvider = new IPMetadataProvider(address(moduleRegistry));
        _postdeploy(contractKey, address(metadataProvider));

        contractKey = "RegistrationModule";
        _predeploy(contractKey);
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry)
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

    function _predeploy(string memory contractKey) private {
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
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
    }

    function _configureModuleRegistry() private {
        moduleRegistry.registerModule("REGISTRATION_MODULE", address(registrationModule));
        moduleRegistry.registerModule("METADATA_RESOLVER_MODULE", address(ipResolver));
    }

    function _configureInteractions() private {
        nftIds[1] = mockNft.mint(deployer);
        nftIds[2] = mockNft.mint(deployer);
        nftIds[3] = mockNft.mint(deployer);
        nftIds[4] = mockNft.mint(deployer);

        // registerIPAccount(deployer, mockNft, token[deployer][mockNft][0]);
        registrationModule.registerRootIp(0, address(mockNft), nftIds[1]);
        registrationModule.registerRootIp(0, address(mockNft), nftIds[2]);

        accessController.setGlobalPermission(
            address(registrationModule),
            address(licenseRegistry),
            bytes4(0), // wildcard
            1 // AccessPermission.ALLOW
        );

        // wildcard allow
        IIPAccount(payable(getIpId(deployer, mockNft, nftIds[1]))).execute(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                getIpId(deployer, mockNft, 1),
                deployer,
                address(0),
                bytes4(0),
                1 // AccessPermission.ALLOW
            )
        );

        /*///////////////////////////////////////////////////////////////
                            CREATE LICENSE FRAMEWORKS
        ////////////////////////////////////////////////////////////////*/

        UMLPolicyFrameworkManager umlAllTrue = new UMLPolicyFrameworkManager(
            address(accessController),
            address(licenseRegistry),
            "https://very-nice-verifier-license.com/{id}.json"
        );
        UMLPolicyFrameworkManager umlMintPayment = new UMLPolicyFrameworkManager(
            address(accessController),
            address(licenseRegistry),
            "https://expensive-minting-license.com/{id}.json"
        );

        frameworkIds["all_true"] = umlAllTrue.register();
        frameworkIds["mint_payment"] = umlMintPayment.register();

        // /*///////////////////////////////////////////////////////////////
        //                         CREATE POLICIES
        // ////////////////////////////////////////////////////////////////*/

        policyIds["test_true"] = umlAllTrue.addPolicy(
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
                distributionChannels: new string[](0)
            })
        );

        policyIds["expensive_mint"] = umlAllTrue.addPolicy(
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
                distributionChannels: new string[](0)
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

        registrationModule.registerDerivativeIp(
            licenseId1,
            address(mockNft),
            nftIds[3],
            "best derivative ip",
            bytes32("some of the best description"),
            "https://example.com/best-derivative-ip"
        );

        // /*///////////////////////////////////////////////////////////////
        //             LINK IPACCOUNTS TO PARENTS USING LICENSES
        // ////////////////////////////////////////////////////////////////*/

        licenseRegistry.linkIpToParent(licenseId1, getIpId(mockNft, nftIds[4]), deployer);
    }

    function getIpId(MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        return ipAccountRegistry.ipAccount(block.chainid, address(mnft), tokenId);
    }

    function getIpId(address user, MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        require(mnft.ownerOf(tokenId) == user, "getIpId: not owner");
        return ipAccountRegistry.ipAccount(block.chainid, address(mnft), tokenId);
    }
}