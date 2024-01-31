// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
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
import { IIPRecordRegistry } from "contracts/interfaces/registries/IIPRecordRegistry.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { IP_RESOLVER_MODULE_KEY, REGISTRATION_MODULE_KEY } from "contracts/lib/modules/Module.sol";
import { IPMetadataProvider } from "contracts/registries/metadata/IPMetadataProvider.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { IPAssetRenderer } from "contracts/registries/metadata/IPAssetRenderer.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { IPResolver } from "contracts/resolvers/IPResolver.sol";
import { RegistrationModule } from "contracts/modules/RegistrationModule.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { RoyaltyPolicyLS } from "contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute-module/policies/ArbitrationPolicySP.sol";

// test
import { MockERC20 } from "test/foundry/mocks/MockERC20.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { MockModule } from "test/foundry/mocks/MockModule.sol";
import { Users, UsersLib } from "test/foundry/utils/Users.sol";

struct MockERC721s {
    MockERC721 ape;
    MockERC721 cat;
    MockERC721 dog;
}

contract BaseIntegration is Test {
    ERC6551Registry internal erc6551Registry;
    IPAccountImpl internal ipAccountImpl;

    // Registry
    IPAccountRegistry internal ipAccountRegistry;
    IPMetadataProvider public ipMetadataProvider;
    IPRecordRegistry internal ipRecordRegistry;
    LicenseRegistry internal licenseRegistry;
    ModuleRegistry internal moduleRegistry;

    // Modules
    RegistrationModule internal registrationModule;
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
    MockERC721s internal erc721;

    // Helpers
    Users internal u;

    // USDC & Liquid Split (ETH Mainnet)
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant LIQUID_SPLIT_FACTORY = 0xdEcd8B99b7F763e16141450DAa5EA414B7994831;
    address internal constant LIQUID_SPLIT_MAIN = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;

    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 USDC

    function setUp() public virtual {
        u = UsersLib.createMockUsers(vm);

        // changePrank(u.admin);

        _deployContracts();
        _configDeployedContracts();
        _deployMockAssets();
        _mintMockAssets();
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
        licenseRegistry = new LicenseRegistry(address(accessController), address(ipAccountRegistry));
        ipRecordRegistry = new IPRecordRegistry(address(moduleRegistry), address(ipAccountRegistry));
        ipResolver = new IPResolver(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry)
        );
        ipMetadataProvider = new IPMetadataProvider(address(moduleRegistry));
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipRecordRegistry),
            address(ipAccountRegistry),
            address(licenseRegistry),
            address(ipResolver),
            address(ipMetadataProvider)
        );
        taggingModule = new TaggingModule();
        royaltyModule = new RoyaltyModule();
        disputeModule = new DisputeModule();
        ipAssetRenderer = new IPAssetRenderer(
            address(ipRecordRegistry),
            address(licenseRegistry),
            address(taggingModule),
            address(royaltyModule)
        );

        arbitrationPolicySP = new ArbitrationPolicySP(address(disputeModule), USDC, ARBITRATION_PRICE);
        royaltyPolicyLS = new RoyaltyPolicyLS(address(royaltyModule), LIQUID_SPLIT_FACTORY, LIQUID_SPLIT_MAIN);
    }

    function _configDeployedContracts() internal {
        vm.startPrank(u.admin);
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));

        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));
        moduleRegistry.registerModule("LICENSE_REGISTRY", address(licenseRegistry));

        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);
        vm.stopPrank();
    }

    function _deployMockAssets() internal {
        erc20 = new MockERC20();
        erc721 = MockERC721s({ ape: new MockERC721("Ape"), cat: new MockERC721("Cat"), dog: new MockERC721("Dog") });
    }

    function _mintMockAssets() internal {
        erc20.mint(u.alice, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.bob, 1000 * 10 ** erc20.decimals());
        erc20.mint(u.carl, 1000 * 10 ** erc20.decimals());
        // skip minting NFTs
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function registerIpAccount(address nft, uint256 tokenId) internal returns (address) {
        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            nft,
            tokenId
        );

        // expect all events below when calling `registrationModule.registerRootIp`

        vm.expectEmit();
        emit IERC6551Registry.ERC6551AccountCreated({
            account: expectedAddr,
            implementation: address(ipAccountImpl),
            salt: ipAccountRegistry.IP_ACCOUNT_SALT(),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPAccountRegistry.IPAccountRegistered({
            account: expectedAddr,
            implementation: address(ipAccountImpl),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPRecordRegistry.IPAccountSet({
            ipId: expectedAddr,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPRecordRegistry.IPResolverSet({
            ipId: expectedAddr,
            resolver: address(ipResolver) // default resolver by Story
        });

        vm.expectEmit();
        emit IIPRecordRegistry.MetadataProviderSet({
            ipId: expectedAddr,
            metadataProvider: address(ipMetadataProvider) // default metadata provider by Story
        });

        vm.expectEmit();
        emit IIPRecordRegistry.IPRegistered({
            ipId: expectedAddr,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId,
            resolver: address(ipResolver), // default resolver by Story
            provider: address(ipMetadataProvider) // default metadata provider by Story
        });

        // TODO: fix msg.sender being different from the prank caller of this function
        //       (since it's another contract calling into this function)
        // vm.expectEmit();
        // emit IRegistrationModule.RootIPRegistered({ caller: address(msg.sender), ipId: expectedAddr, policyId: 0 });

        // policyId = 0 means no policy attached directly on creation
        return registrationModule.registerRootIp(0, nft, tokenId);
    }

    function registerIpAccount(MockERC721 nft, uint256 tokenId) internal returns (address) {
        return registerIpAccount(address(nft), tokenId);
    }

    function registerDerivativeIp(
        uint256 licenseId,
        address nft,
        uint256 tokenId,
        string memory ipName,
        bytes32 contentHash,
        string memory externalUrl,
        address caller
    ) internal returns (address) {
        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            nft,
            tokenId
        );

        vm.expectEmit();
        emit IERC6551Registry.ERC6551AccountCreated({
            account: expectedAddr,
            implementation: address(ipAccountImpl),
            salt: ipAccountRegistry.IP_ACCOUNT_SALT(),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPAccountRegistry.IPAccountRegistered({
            account: expectedAddr,
            implementation: address(ipAccountImpl),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPRecordRegistry.IPAccountSet({
            ipId: expectedAddr,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPRecordRegistry.IPResolverSet({
            ipId: expectedAddr,
            resolver: address(ipResolver) // default resolver by Story
        });

        vm.expectEmit();
        emit IIPRecordRegistry.MetadataProviderSet({
            ipId: expectedAddr,
            metadataProvider: address(ipMetadataProvider) // default metadata provider by Story
        });

        vm.expectEmit();
        emit IIPRecordRegistry.IPRegistered({
            ipId: expectedAddr,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId,
            resolver: address(ipResolver), // default resolver by Story
            provider: address(ipMetadataProvider) // default metadata provider by Story
        });

        address ipId = expectedAddr;
        uint256 policyId = licenseRegistry.policyIdForLicense(licenseId);
        address parentIpId = licenseRegistry.licensorIpId(licenseId);
        uint256 newPolicyIndex = licenseRegistry.totalPoliciesForIp(ipId);

        // Note that below events are emitted in function that's called by the registration module.

        vm.expectEmit();
        emit ILicenseRegistry.PolicyAddedToIpId({
            caller: address(registrationModule),
            ipId: ipId,
            policyId: policyId,
            index: newPolicyIndex,
            inheritedPolicy: true
        });

        vm.expectEmit();
        emit ILicenseRegistry.IpIdLinkedToParent({
            caller: address(registrationModule),
            ipId: ipId,
            parentIpId: parentIpId
        });

        vm.expectEmit();
        emit IERC1155.TransferSingle({
            operator: address(registrationModule),
            from: caller,
            to: address(0), // burn addr
            id: policyId,
            value: 1
        });

        vm.expectEmit();
        emit IRegistrationModule.DerivativeIPRegistered({ caller: caller, ipId: ipId, licenseId: licenseId });

        registrationModule.registerDerivativeIp(licenseId, nft, tokenId, ipName, contentHash, externalUrl);
        return ipId;
    }

    function linkIpToParent(uint256 licenseId, address ipId, address caller) internal {
        uint256 policyId = licenseRegistry.policyIdForLicense(licenseId);
        address parentIpId = licenseRegistry.licensorIpId(licenseId);
        uint256 newPolicyIndex = licenseRegistry.totalPoliciesForIp(ipId);

        vm.expectEmit();
        emit ILicenseRegistry.PolicyAddedToIpId({
            caller: caller,
            ipId: ipId,
            policyId: policyId,
            index: newPolicyIndex,
            inheritedPolicy: true
        });

        vm.expectEmit();
        emit ILicenseRegistry.IpIdLinkedToParent({ caller: caller, ipId: ipId, parentIpId: parentIpId });

        vm.expectEmit();
        emit IERC1155.TransferSingle({
            operator: caller,
            from: caller,
            to: address(0), // burn addr
            id: policyId,
            value: 1
        });

        licenseRegistry.linkIpToParent(licenseId, ipId, caller);
    }
}
