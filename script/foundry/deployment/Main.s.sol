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
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { MockERC721 } from "contracts/mocks/MockERC721.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { Governance } from "contracts/governance/Governance.sol";

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
    IPRecordRegistry public ipRecordRegistry;
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
    mapping(uint256 => uint256) internal policyIds;
    mapping(string => uint256) internal fwIds;
    mapping(string => Licensing.FrameworkCreationParams) internal fwCreationParams;
    mapping(string => Licensing.Policy) internal policies;

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

        mockNft = new MockERC721();

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

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        licenseRegistry = new LicenseRegistry("https://example.com/{id}.json");
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "IPAccountRegistry";
        _predeploy(contractKey);
        ipAccountRegistry = new IPAccountRegistry(ERC6551_REGISTRY, address(accessController), address(implementation));
        _postdeploy(contractKey, address(ipAccountRegistry));

        contractKey = "IPRecordRegistry";
        _predeploy(contractKey);
        ipRecordRegistry = new IPRecordRegistry(address(moduleRegistry), address(ipAccountRegistry));
        _postdeploy(contractKey, address(ipRecordRegistry));

        contractKey = "IPResolver";
        _predeploy(contractKey);
        ipResolver = new IPResolver(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
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
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry),
            address(ipResolver),
            address(metadataProvider)
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
            address(ipRecordRegistry),
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
        // _configureIPRecordRegistry();
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

        fwCreationParams["all_true"] = Licensing.FrameworkCreationParams({
            parameters: new IParamVerifier[](0),
            defaultValues: new bytes[](0),
            licenseUrl: "https://very-nice-verifier-license.com"
        });

        fwCreationParams["mint_payment"] = Licensing.FrameworkCreationParams({
            parameters: new IParamVerifier[](0),
            defaultValues: new bytes[](0),
            licenseUrl: "https://expensive-minting-license.com"
        });

        fwIds["all_true"] = licenseRegistry.addLicenseFramework(fwCreationParams["all_true"]);
        fwIds["mint_payment"] = licenseRegistry.addLicenseFramework(fwCreationParams["mint_payment"]);

        // /*///////////////////////////////////////////////////////////////
        //                         CREATE POLICIES
        // ////////////////////////////////////////////////////////////////*/

        policies["test_true"] = Licensing.Policy({
            frameworkId: fwIds["all_true"],
            commercialUse: true,
            derivatives: true,
            paramNames: new bytes32[](0),
            paramValues: new bytes[](0)
        });

        policies["expensive_mint"] = Licensing.Policy({
            frameworkId: fwIds["mint_payment"],
            commercialUse: true,
            derivatives: true,
            paramNames: new bytes32[](0),
            paramValues: new bytes[](0)
        });

        uint256 policyId_test_true = licenseRegistry.addPolicy(policies["test_true"]);
        uint256 policyId_exp_mint = licenseRegistry.addPolicy(policies["expensive_mint"]);

        // /*///////////////////////////////////////////////////////////////
        //                     ADD POLICIES TO IPACCOUNTS
        // ////////////////////////////////////////////////////////////////*/

        licenseRegistry.addPolicyToIp(getIpId(mockNft, nftIds[1]), policyId_test_true);
        licenseRegistry.addPolicyToIp(getIpId(mockNft, nftIds[2]), policyId_exp_mint);

        // /*///////////////////////////////////////////////////////////////
        //                     MINT LICENSES ON POLICIES
        // ////////////////////////////////////////////////////////////////*/

        // Mints 1 license for policy "test_true" on NFT id 1 IPAccount
        uint256 licenseId1 = licenseRegistry.mintLicense(policyId_test_true, getIpId(mockNft, nftIds[1]), 2, deployer);

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
