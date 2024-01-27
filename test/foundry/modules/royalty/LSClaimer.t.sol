// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { console2 } from "forge-std/console2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TestHelper } from "../../../utils/TestHelper.sol";
import { ILiquidSplitFactory } from "../../../../contracts/interfaces/modules/royalty/policies/ILiquidSplitFactory.sol";
import { LSClaimer } from "../../../../contracts/modules/royalty-module/policies/LSClaimer.sol";

// setup imports
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

contract TestLSClaimer is TestHelper {
    address[] public LONGEST_CHAIN = new address[](0);
    address[] public accounts = new address[](2);
    uint32[] public initAllocations = new uint32[](2);

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

    RegistrationModule public registrationModule;
    TaggingModule public taggingModule;
    IPResolver public ipResolver;

    mapping(uint256 => uint256) internal nftIds;
    mapping(uint256 => uint256) internal policyIds;
    mapping(string => uint256) internal fwIds;
    mapping(string => Licensing.FrameworkCreationParams) internal fwCreationParams;
    mapping(string => Licensing.Policy) internal policies;

    function setUp() public override {
        super.setUp();

        /*///////////////////////////////////////////////////////////////
                            DEPLOY PROTOCOL CONTRACTS
        ////////////////////////////////////////////////////////////////*/

        mockNft = new MockERC721();
        accessController = new AccessController();
        implementation = new IPAccountImpl();
        moduleRegistry = new ModuleRegistry();
        licenseRegistry = new LicenseRegistry("https://example.com/{id}.json");
        ipAccountRegistry = new IPAccountRegistry(ERC6551_REGISTRY, address(accessController), address(implementation));
        ipRecordRegistry = new IPRecordRegistry(address(moduleRegistry), address(ipAccountRegistry));
        ipResolver = new IPResolver(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry)
        );
        metadataProvider = new IPMetadataProvider(address(moduleRegistry));
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry),
            address(ipResolver),
            address(metadataProvider)
        );
        taggingModule = new TaggingModule();
        renderer = new IPAssetRenderer(
            address(ipRecordRegistry),
            address(licenseRegistry),
            address(taggingModule),
            address(royaltyModule)
        );

        // configure
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
        moduleRegistry.registerModule("REGISTRATION_MODULE", address(registrationModule));
        moduleRegistry.registerModule("IP_RESOLVER_MODULE", address(ipResolver));

        /*///////////////////////////////////////////////////////////////
                            MINT NFTS AND REGISTER ROOT
        ////////////////////////////////////////////////////////////////*/

        // mint 1000 nfts
        for (uint256 i = 1; i < 1002; i++) {
            nftIds[i] = mockNft.mint(deployer);
        }

        // register one root ip
        vm.startPrank(deployer);
        registrationModule.registerRootIp(0, address(mockNft), nftIds[1]);
        vm.stopPrank();

        // set permissions
        accessController.setGlobalPermission(
            address(registrationModule),
            address(licenseRegistry),
            bytes4(0), // wildcard
            1 // AccessPermission.ALLOW
        );

        // wildcard allow
        vm.startPrank(deployer);
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
        vm.stopPrank();

        /*///////////////////////////////////////////////////////////////
                            CREATE LICENSE FRAMEWORKS
        ////////////////////////////////////////////////////////////////*/

        fwCreationParams["all_true"] = Licensing.FrameworkCreationParams({
            parameters: new IParamVerifier[](0),
            defaultValues: new bytes[](0),
            licenseUrl: "https://very-nice-verifier-license.com"
        });

        fwIds["all_true"] = licenseRegistry.addLicenseFramework(fwCreationParams["all_true"]);

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

        uint256 policyId_test_true = licenseRegistry.addPolicy(policies["test_true"]);

        // /*///////////////////////////////////////////////////////////////
        //                     MINT LICENSES ON POLICIES
        // ////////////////////////////////////////////////////////////////*/

        // Mints 1 license for policy "test_true" on NFT id 1 IPAccount
        vm.startPrank(deployer);
        licenseRegistry.addPolicyToIp(getIpId(mockNft, nftIds[1]), policyId_test_true);
        for (uint256 i = 1; i < 1001; i++) {
            uint256 licenseId = licenseRegistry.mintLicense(policyId_test_true, getIpId(mockNft, nftIds[i]), 2, deployer);

            registrationModule.registerDerivativeIp(
                licenseId,
                address(mockNft),
                nftIds[i+1],
                "",
                bytes32("0"),
                ""
            );  
        }
        vm.stopPrank();

        // /*///////////////////////////////////////////////////////////////
        //                     SET UP LSCLAIMER
        // ////////////////////////////////////////////////////////////////*/

        lsClaimer = new LSClaimer(address(1), address(1), address(licenseRegistry));
        
        accounts[0] = ipAccount3;
        accounts[1] = address(lsClaimer);

        initAllocations[0] = 100;
        initAllocations[1] = 900;

        address splitClone = ILiquidSplitFactory(LIQUID_SPLIT_FACTORY).createLiquidSplitClone(
            accounts,
            initAllocations,
            0, // distributorFee
            address(0) // splitOwner
        );

        lsClaimer.setRNFT(splitClone);

        // set up longest chain possible of 1000 elements
        for (uint256 i = 0; i < 999; i++) {
            LONGEST_CHAIN.push(getIpId(mockNft, nftIds[i+1]));
        }
        assertEq(LONGEST_CHAIN.length, 999);
    }

    // TODO: can delete transfer benchmark
    function test_transferBenchmark() public {
        vm.startPrank(USDC_RICH);
        IERC20(USDC).transfer(address(1), 1000);
    }
    function test_LSClaimer_claim() public {


        lsClaimer.claim(LONGEST_CHAIN, getIpId(mockNft, nftIds[1]));

        console2.log("isParent1",licenseRegistry.isParent(getIpId(mockNft, nftIds[1000]), getIpId(mockNft, nftIds[1001])));
        console2.log("isParent2",licenseRegistry.isParent(getIpId(mockNft, nftIds[999]), getIpId(mockNft, nftIds[1000])));
    }

    // Helper functions
    function getIpId(MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        return ipAccountRegistry.ipAccount(block.chainid, address(mnft), tokenId);
    }
    function getIpId(address user, MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        require(mnft.ownerOf(tokenId) == user, "getIpId: not owner");
        return ipAccountRegistry.ipAccount(block.chainid, address(mnft), tokenId);
    }

    function _deployProtocolContracts(address accessControldeployer) private {


        // mockModule = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule");
    }
}