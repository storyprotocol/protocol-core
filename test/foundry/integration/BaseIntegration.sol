// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

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
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { RoyaltyPolicyLS } from "contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { TaggingModule } from "contracts/modules/tagging/TaggingModule.sol";
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute-module/policies/ArbitrationPolicySP.sol";

// test
import { MockERC20 } from "test/foundry/mocks/MockERC20.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { MockUSDC } from "test/foundry/mocks/MockUSDC.sol";
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
    IPAssetRegistry internal ipAssetRegistry;
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
    MockUSDC internal USDC;

    // Helpers
    Users internal u;

    // 0xSplits Liquid Split (Sepolia)
    address internal constant LIQUID_SPLIT_FACTORY = 0xF678Bae6091Ab6933425FE26Afc20Ee5F324c4aE;
    address internal constant LIQUID_SPLIT_MAIN = 0x57CBFA83f000a38C5b5881743E298819c503A559;

    uint256 internal constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 USDC

    function setUp() public virtual {
        u = UsersLib.createMockUsers(vm);

        // changePrank(u.admin);

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
        licenseRegistry = new LicenseRegistry(address(accessController), address(ipAccountRegistry));
        ipMetadataProvider = new IPMetadataProvider(address(moduleRegistry));
        ipAssetRegistry = new IPAssetRegistry(
            address(accessController),
            address(erc6551Registry),
            address(ipAccountImpl)
        );
        ipResolver = new IPResolver(address(accessController), address(ipAssetRegistry), address(licenseRegistry));
        registrationModule = new RegistrationModule(
            address(accessController),
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(ipResolver)
        );
        taggingModule = new TaggingModule();
        royaltyModule = new RoyaltyModule();
        disputeModule = new DisputeModule();
        ipAssetRenderer = new IPAssetRenderer(
            address(ipAssetRegistry),
            address(licenseRegistry),
            address(taggingModule),
            address(royaltyModule)
        );

        arbitrationPolicySP = new ArbitrationPolicySP(address(disputeModule), address(USDC), ARBITRATION_PRICE);
        royaltyPolicyLS = new RoyaltyPolicyLS(
            address(royaltyModule),
            address(licenseRegistry),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN
        );

        vm.label(LIQUID_SPLIT_FACTORY, "LIQUID_SPLIT_FACTORY");
        vm.label(LIQUID_SPLIT_MAIN, "LIQUID_SPLIT_MAIN");
    }

    function _configDeployedContracts() internal {
        vm.startPrank(u.admin);
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));

        moduleRegistry.registerModule(REGISTRATION_MODULE_KEY, address(registrationModule));
        moduleRegistry.registerModule(IP_RESOLVER_MODULE_KEY, address(ipResolver));
        moduleRegistry.registerModule("LICENSE_REGISTRY", address(licenseRegistry));

        // whitelist royalty policy
        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);
        // whitelist royalty token
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
            address(licenseRegistry),
            bytes4(licenseRegistry.linkIpToParent.selector),
            1 // AccessPermission.ALLOW
        );

        accessController.setGlobalPermission(
            address(licenseRegistry),
            address(royaltyModule),
            bytes4(royaltyModule.setRoyaltyPolicy.selector),
            1 // AccessPermission.ALLOW
        );

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function registerIpAccount(address nft, uint256 tokenId, address caller) internal returns (address) {
        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            nft,
            tokenId
        );

        vm.label(expectedAddr, string(abi.encodePacked("IPAccount", Strings.toString(tokenId))));

        bytes memory metadata = abi.encode(
            IP.MetadataV1({
                name: string(abi.encodePacked("IPAccount", Strings.toString(tokenId))),
                hash: bytes32("ip account hash"),
                registrationDate: uint64(block.timestamp),
                registrant: caller,
                uri: "external URL"
            })
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
        emit IIPAssetRegistry.IPResolverSet({
            ipId: expectedAddr,
            resolver: address(ipResolver) // default resolver for new IP registrations
        });

        vm.expectEmit();
        emit IIPAssetRegistry.MetadataSet({
            ipId: expectedAddr,
            metadataProvider: ipAssetRegistry.metadataProvider(), // default metadata provider for new IP registrations
            metadata: metadata
        });

        vm.expectEmit();
        emit IIPAssetRegistry.IPRegistered({
            ipId: expectedAddr,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId,
            resolver: address(ipResolver), // default resolver for new IP registrations
            provider: ipAssetRegistry.metadataProvider(), // default metadata provider for new IP registrations
            metadata: metadata
        });

        vm.expectEmit();
        emit IRegistrationModule.RootIPRegistered({ caller: caller, ipId: expectedAddr, policyId: 0 });

        // policyId = 0 means no policy attached directly on creation
        vm.startPrank(caller);
        return registrationModule.registerRootIp(0, nft, tokenId, metadata);
    }

    function registerIpAccount(MockERC721 nft, uint256 tokenId, address caller) internal returns (address) {
        return registerIpAccount(address(nft), tokenId, caller);
    }

    function registerDerivativeIp(
        uint256 licenseId,
        address nft,
        uint256 tokenId,
        IP.MetadataV1 memory metadata,
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

        vm.label(expectedAddr, string(abi.encodePacked("IPAccount", Strings.toString(tokenId))));

        uint256 policyId = licenseRegistry.policyIdForLicense(licenseId);
        address parentIpId = licenseRegistry.licensorIpId(licenseId);
        uint256 newPolicyIndex = licenseRegistry.totalPoliciesForIp(expectedAddr);

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
        emit IIPAssetRegistry.IPResolverSet({
            ipId: expectedAddr,
            resolver: address(ipResolver) // default resolver for new IP registrations
        });

        vm.expectEmit();
        emit IIPAssetRegistry.MetadataSet({
            ipId: expectedAddr,
            metadataProvider: ipAssetRegistry.metadataProvider(), // default metadata provider for new IP registrations
            metadata: abi.encode(metadata)
        });

        vm.expectEmit();
        emit IIPAssetRegistry.IPRegistered({
            ipId: expectedAddr,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId,
            resolver: address(ipResolver), // default resolver for new IP registrations
            provider: ipAssetRegistry.metadataProvider(), // default metadata provider for new IP registrations
            metadata: abi.encode(metadata)
        });

        // Note that below events are emitted in function that's called by the registration module.

        vm.expectEmit();
        emit ILicenseRegistry.PolicyAddedToIpId({
            caller: address(registrationModule),
            ipId: expectedAddr,
            policyId: policyId,
            index: newPolicyIndex,
            inheritedPolicy: true
        });

        vm.expectEmit();
        emit ILicenseRegistry.IpIdLinkedToParent({
            caller: address(registrationModule),
            ipId: expectedAddr,
            parentIpId: parentIpId
        });

        vm.expectEmit();
        emit IERC1155.TransferSingle({
            operator: address(registrationModule),
            from: caller,
            to: address(0), // burn addr
            id: licenseId,
            value: 1
        });

        vm.expectEmit();
        emit IRegistrationModule.DerivativeIPRegistered({ caller: caller, ipId: expectedAddr, licenseId: licenseId });

        vm.startPrank(caller);
        registrationModule.registerDerivativeIp(licenseId, nft, tokenId, metadata.name, metadata.hash, metadata.uri);
        return expectedAddr;
    }

    function linkIpToParent(uint256 licenseId, address ipId, address caller) internal {
        uint256 policyId = licenseRegistry.policyIdForLicense(licenseId);
        address parentIpId = licenseRegistry.licensorIpId(licenseId);
        uint256 newPolicyIndex = licenseRegistry.totalPoliciesForIp(ipId);

        uint256 prevLicenseAmount = licenseRegistry.balanceOf(caller, licenseId);

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
            id: licenseId,
            value: 1
        });

        vm.startPrank(caller);
        licenseRegistry.linkIpToParent(licenseId, ipId, caller);

        assertEq(licenseRegistry.balanceOf(caller, licenseId), prevLicenseAmount - 1, "license not burnt on linking");
        assertTrue(licenseRegistry.isParent(parentIpId, ipId), "parent IP account is not parent");
        assertEq(
            keccak256(
                abi.encode(
                    licenseRegistry.policyForIpAtIndex(
                        parentIpId,
                        licenseRegistry.indexOfPolicyForIp(parentIpId, policyId)
                    )
                )
            ),
            keccak256(abi.encode(licenseRegistry.policyForIpAtIndex(ipId, newPolicyIndex))),
            "policy not the same in parent to child"
        );
    }
}
