/* solhint-disable no-console */
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Script } from "forge-std/Script.sol";
import { Test } from "forge-std/Test.sol";
import { stdJson } from "forge-std/StdJson.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";

import { AccessController } from "contracts/AccessController.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { IPMetadataResolver } from "contracts/resolvers/IPMetadataResolver.sol";

import { MockERC20 } from "test/foundry/mocks/MockERC20.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { MockModule } from "test/foundry/mocks/MockModule.sol";
import { MockIParamVerifier } from "test/foundry/mocks/licensing/MockParamVerifier.sol";
import { MintPaymentVerifier } from "test/foundry/mocks/licensing/MintPaymentVerifier.sol";
import { Users, UsersLib } from "test/foundry/utils/Users.sol";
// script
import { StringUtil } from "script/foundry/utils/StringUtil.sol";
import { BroadcastManager } from "script/foundry/utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "script/foundry/utils/JsonDeploymentHandler.s.sol";

contract Integration is Script, BroadcastManager, JsonDeploymentHandler {
    using StringUtil for uint256;
    using stdJson for string;

    using EnumerableSet for EnumerableSet.UintSet;

    AccessController internal accessController = AccessController(0x97738c808F032226B26bF3d292261976c7c6D530);
    ERC6551Registry internal erc6551Registry = ERC6551Registry(0x000000006551c19487814612e58FE06813775758);
    IPAccountImpl internal ipacctImpl = IPAccountImpl(payable(0x97527BB0435B28836489ac3E1577cA1e2a099371));
    IPAccountRegistry internal ipacctRegistry = IPAccountRegistry(0x12054FC0F26F979b271dE691358FeDCF5a1DAe65);
    LicenseRegistry internal licenseRegistry = LicenseRegistry(0xe2Cb2839a1840F3f6bfC2d5508B4a60bF81C1738);
    ModuleRegistry internal moduleRegistry = ModuleRegistry(0xE48ce7F62Ddcc0339b0B4ca56A600aA31bc4479c);
    DisputeModule internal disputeModule = DisputeModule(0x9e94233357f3Ff8FEc75E45cF759f48937CA985d);
    RegistrationModule internal registrationModule = RegistrationModule(0x72632232caBF975dA1AedCB46062844E16234713);
    IPMetadataResolver internal ipResolver = IPMetadataResolver(0x88f3a4cc4Eaa2433c44A7c502C7AbBd2C76b03e2);
    TaggingModule internal taggingModule = TaggingModule(0xC00744062741d2256e13a267aa9f30d186bfF610);
    // RegistrationModule internal registrationModule = new RegistrationModule(
    // 	address(accessController),
    // 	address(ipacctRegistry),
    // 	address(moduleRegistry),
    // 	address(licenseRegistry),
    // 	address(0x000000006551c19487814612e58FE06813775758)
    // );

    // Sepolia mock tokens
    MockERC20 internal mockToken = MockERC20(0xeA12CB8429736Db937d6C727b003a9D94cCf5DF3);
    MockERC721 internal nft = MockERC721(0xB464F4582e62F6eB3CF506E4135f92BD198EB03E);
    // MockIParamVerifier public mockLicenseVerifier = new MockIParamVerifier();
    // MintPaymentVerifier internal mintPaymentVerifier;

    // IPAccounts
    mapping(address userAddr => mapping(MockERC721 nft => mapping(uint256 tokenId => address ipId))) internal ipacct;

    // NFT Token IDs List by User
    mapping(address userAddr => mapping(MockERC721 nft => uint256[] tokenIds)) internal token;

    // NFT Token IDs Set by User
    mapping(address userAddr => mapping(MockERC721 nft => EnumerableSet.UintSet tokenIdSet)) internal tokenSet;

    mapping(string frameworkName => Licensing.FrameworkCreationParams) internal licenseFwCreations;

    mapping(string frameworkName => uint256 frameworkId) internal licenseFwIds;
    mapping(uint256 frameworkId => string frameworkName) internal licenseFwNames; // reverse of licenseFwIds

    mapping(string policyName => Licensing.Policy) internal policy;

    mapping(string policyName => mapping(address userAddr => uint256 policyId)) internal policyIds;

    mapping(address userAddr => mapping(uint256 policyId => uint256 licenseId)) internal licenseIds;

    mapping(address userAddr => uint256 balance) internal mockTokenBalanceBefore;

    mapping(address userAddr => uint256 balance) internal mockTokenBalanceAfter;

    address internal admin;

    constructor() JsonDeploymentHandler("pd-integration") {}

    function setUp() public {
        // accessController.initialize(address(ipacctRegistry), address(moduleRegistry));
        // moduleRegistry.registerModule("REGISTRATION_MODULE", address(registrationModule));
        // moduleRegistry.registerModule("METADATA_RESOLVER_MODULE", address(ipResolver));
        // moduleRegistry.registerModule("TAGGING_MODULE", address(taggingModule));
    }

    function run() public {
        _beginBroadcast();

        admin = deployer;

        taggingModule.setTag("luxury", ipacctRegistry.ipAccount(block.chainid, address(nft), 1));
        taggingModule.setTag("authentic", ipacctRegistry.ipAccount(block.chainid, address(nft), 2));
        taggingModule.setTag("premium", ipacctRegistry.ipAccount(block.chainid, address(nft), 3));

        // uint256 id1 = mintNFT(admin, nft);
        // uint256 id2 = mintNFT(admin, nft);
        // uint256 id3 = mintNFT(admin, nft);
        // uint256 id4 = mintNFT(admin, nft);

        // // registerIPAccount(admin, nft, token[admin][nft][0]);
        // // registerIPAccount(admin, nft, token[admin][nft][1]);
		// 		registrationModule.registerRootIp(0, address(nft), id1);

        // // wildcard allow
        // IIPAccount(payable(getIpId(admin, nft, 1))).execute(
        //     address(accessController),
        //     0,
        //     abi.encodeWithSignature(
        //         "setPermission(address,address,address,bytes4,uint8)",
        //         getIpId(admin, nft, 1),
        //         admin,
        //         address(0),
        //         bytes4(0),
        //         1 // AccessPermission.ALLOW
        //     )
        // );

        // /*///////////////////////////////////////////////////////////////
        //                     CREATE LICENSE FRAMEWORKS
        // ////////////////////////////////////////////////////////////////*/

        // // All trues for MockVerifier means it will always return true on condition checks
        // bytes[] memory byteValueTrue = new bytes[](1);
        // byteValueTrue[0] = abi.encode(true);

        // // Licensing.FrameworkCreationParams memory fwAllTrue = Licensing.FrameworkCreationParams({
        // //     mintingParamVerifiers: new IParamVerifier[](1),
        // //     mintingParamDefaultValues: byteValueTrue,
        // //     activationParamVerifiers: new IParamVerifier[](1),
        // //     activationParamDefaultValues: byteValueTrue,
        // //     defaultNeedsActivation: true,
        // //     linkParentParamVerifiers: new IParamVerifier[](1),
        // //     linkParentParamDefaultValues: byteValueTrue,
        // //     licenseUrl: "https://very-nice-verifier-license.com"
        // // });
        // Licensing.FrameworkCreationParams memory fwAllTrue = Licensing.FrameworkCreationParams({
        //     mintingParamVerifiers: new IParamVerifier[](0),
        //     mintingParamDefaultValues: new bytes[](0),
        //     // mintingParamDefaultValues: byteValueTrue,
        //     activationParamVerifiers: new IParamVerifier[](0),
        //     activationParamDefaultValues: new bytes[](0),
        //     // activationParamDefaultValues: byteValueTrue,
        //     defaultNeedsActivation: true,
        //     linkParentParamVerifiers: new IParamVerifier[](0),
        //     linkParentParamDefaultValues: new bytes[](0),
        //     // linkParentParamDefaultValues: byteValueTrue,
        //     licenseUrl: "https://very-nice-verifier-license.com"
        // });

        // // fwAllTrue.mintingParamVerifiers[0] = mockLicenseVerifier;
        // // fwAllTrue.activationParamVerifiers[0] = mockLicenseVerifier;
        // // fwAllTrue.linkParentParamVerifiers[0] = mockLicenseVerifier;

        // Licensing.FrameworkCreationParams memory fwMintPayment = Licensing.FrameworkCreationParams({
        //     mintingParamVerifiers: new IParamVerifier[](0),
        //     mintingParamDefaultValues: new bytes[](0),
        //     // mintingParamVerifiers: new IParamVerifier[](1),
        //     // mintingParamDefaultValues: byteValueTrue, // value here doesn't matter for MintPaymentVerifier
        //     activationParamVerifiers: new IParamVerifier[](0),
        //     activationParamDefaultValues: new bytes[](0),
        //     defaultNeedsActivation: false,
        //     linkParentParamVerifiers: new IParamVerifier[](0),
        //     linkParentParamDefaultValues: new bytes[](0),
        //     licenseUrl: "https://expensive-minting-license.com"
        // });

        // // fwMintPayment.mintingParamVerifiers[0] = mintPaymentVerifier;

        // addLicenseFramework("all_true", fwAllTrue);
        // addLicenseFramework("mint_payment", fwMintPayment);

        // // /*///////////////////////////////////////////////////////////////
        // //                         CREATE POLICIES
        // // ////////////////////////////////////////////////////////////////*/

        // policy["test_true"] = Licensing.Policy({
        //     frameworkId: licenseFwIds["all_true"],
        //     mintingParamValues: new bytes[](0),
        //     activationParamValues: new bytes[](0),
        //     needsActivation: true,
        //     linkParentParamValues: new bytes[](0)
        // });

        // policy["expensive_mint"] = Licensing.Policy({
        //     frameworkId: licenseFwIds["mint_payment"],
        //     mintingParamValues: new bytes[](0),
        //     activationParamValues: new bytes[](0),
        //     needsActivation: false,
        //     linkParentParamValues: new bytes[](0)
        // });

        // (uint256 policyId_test_true, ) = licenseRegistry.addPolicy(policy["test_true"]);
        // (uint256 policyId_exp_mint, ) = licenseRegistry.addPolicy(policy["expensive_mint"]);

        // /*///////////////////////////////////////////////////////////////
        //                     ADD POLICIES TO IPACCOUNTS
        // ////////////////////////////////////////////////////////////////*/

        // attachPolicyToIPID(getIpId(admin, nft, 1), "test_true");
        // attachPolicyToIPID(getIpId(admin, nft, 2), "expensive_mint");

        // registrationModule.registerRootIp(0, address(nft), 1);
        // registrationModule.registerDerivativeIP

        // /*///////////////////////////////////////////////////////////////
        //                     MINT LICENSES ON POLICIES
        // ////////////////////////////////////////////////////////////////*/

        // Licensing.License memory licenseData = Licensing.License({
        //     policyId: policyIds["test_true"][getIpId(admin, nft, 1)],
        //     licensorIpIds: new address[](1)
        // });
        // licenseData.licensorIpIds[0] = getIpId(admin, nft, 1);

        // // Mints 1 license for policy "test_true" on NFT id 1 IPAccount
        // licenseIds[admin][policyIds["test_true"][getIpId(admin, nft, 1)]] = licenseRegistry.mintLicense(
        //     licenseData,
        //     1,
        //     admin
        // );

        // /*///////////////////////////////////////////////////////////////
        //             LINK IPACCOUNTS TO PARENTS USING LICENSES
        // ////////////////////////////////////////////////////////////////*/

        // // Activate above license on NFT id 2 IPAccount, linking as child to NFT id 1 IPAccount

        // licenseRegistry.linkIpToParent(
        //     licenseIds[admin][policyIds["test_true"][getIpId(admin, nft, 1)]],
        //     getIpId(admin, nft, 2),
        //     admin
        // );
        _endBroadcast();
    }

    function mintNFT(address to, MockERC721 mnft) internal returns (uint256 tokenId) {
        tokenId = mnft.mint(to);
        token[to][mnft].push(tokenId);
        tokenSet[to][mnft].add(tokenId);
    }

    function transferNFT(address from, address to, MockERC721 mnft, uint256 tokenId) internal {
        removeIdFromTokenData(from, mnft, tokenId);
        token[to][mnft].push(tokenId);
        tokenSet[to][mnft].add(tokenId);
        mnft.transferFrom(from, to, tokenId);
    }

    function removeIdFromTokenData(address user, MockERC721 mnft, uint256 tokenId) internal {
        uint256[] storage arr = token[user][mnft];
        require(tokenSet[user][mnft].contains(tokenId), "tokenId not found in tokenSet");
        uint256 index = tokenId - 1; // tokenId starts from 1
        require(index < arr.length, "tokenId index out of range");
        // remove certain index from array while maintaing order
        for (uint256 i = index; i < arr.length - 1; ++i) {
            arr[i] = arr[i + 1];
        }
        arr.pop();
        // delete arr[arr.length - 1];
        // arr.length--;
        tokenSet[user][mnft].remove(tokenId);
    }

    function registerIPAccount(address user, MockERC721 mnft, uint256 tokenId) public returns (address ipId) {
        ipId = ipacctRegistry.registerIpAccount(block.chainid, address(mnft), tokenId);
        ipacct[user][mnft][tokenId] = ipId;
    }

    function getIpId(address user, MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        require(mnft.ownerOf(tokenId) == user, "getIpId: not owner");
        ipId = ipacct[user][mnft][tokenId];
        require(ipId == ipacctRegistry.ipAccount(block.chainid, address(mnft), tokenId));
    }

    function addLicenseFramework(
        string memory name,
        Licensing.FrameworkCreationParams memory params
    ) public returns (uint256 fwId) {
        require(licenseFwIds[name] == 0, "Framework already exists");
        licenseFwCreations[name] = params;
        fwId = licenseRegistry.addLicenseFramework(params);

        licenseFwIds[name] = fwId;
        licenseFwNames[fwId] = name;
    }

    function attachPolicyToIPID(
        address ipId,
        string memory policyName
    ) public returns (uint256 policyId, bool isNew, uint256 indexOnIpId) {
        (policyId, isNew, indexOnIpId) = licenseRegistry.addPolicyToIp(ipId, policy[policyName]);
        policyIds[policyName][ipId] = policyId;
    }

    function attachPolicyAndMintLicenseForIPID(
        address ipId,
        string memory policyName,
        address licensee,
        uint256 amount
    ) public returns (uint256 licenseId) {
        (uint256 policyId, bool isNew, uint256 indexOnIpId) = attachPolicyToIPID(ipId, policyName);
        Licensing.License memory licenseData = Licensing.License({
            policyId: policyId,
            licensorIpIds: new address[](1)
        });
        licenseData.licensorIpIds[0] = ipId;
        licenseId = licenseRegistry.mintLicense(licenseData, amount, licensee);
        licenseIds[licensee][policyId] = licenseId;
    }
}
