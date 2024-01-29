// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";

import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { DisputeModule } from "contracts/modules/dispute-module/DisputeModule.sol";
import { ArbitrationPolicySP } from "contracts/modules/dispute-module/policies/ArbitrationPolicySP.sol";
import { RoyaltyModule } from "contracts/modules/royalty-module/RoyaltyModule.sol";
import { RoyaltyPolicyLS } from "contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { UMLPolicyFrameworkManager, UMLv1Policy } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { MockERC20 } from "test/foundry/mocks/MockERC20.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { MockModule } from "test/foundry/mocks/MockModule.sol";
import { MockPolicyFrameworkManager, MockPolicyFrameworkConfig, MockPolicy } from "test/foundry/mocks/licensing/MockPolicyFrameworkManager.sol";
import { MintPaymentPolicyFrameworkManager, MintPaymentPolicy } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";
import { Users, UsersLib } from "test/foundry/utils/Users.sol";

struct MockERC721s {
    MockERC721 a;
    MockERC721 b;
    MockERC721 c;
}

contract IntegrationTest is Test {
    using EnumerableSet for EnumerableSet.UintSet;

    ERC6551Registry internal erc6551Registry = new ERC6551Registry();
    IPAccountImpl internal ipacctImpl;
    IPAccountRegistry internal ipacctRegistry;
    LicenseRegistry internal licenseRegistry;

    DisputeModule internal disputeModule;
    ArbitrationPolicySP internal arbitrationPolicySP;
    RoyaltyModule internal royaltyModule;
    RoyaltyPolicyLS internal royaltyPolicyLS;

    MockAccessController internal accessController = new MockAccessController();
    MockERC20 internal mockToken = new MockERC20();
    MockERC721s internal nft;

    Users internal u;

    // USDC (ETH Mainnet)
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDC_RICH = 0xcEe284F754E854890e311e3280b767F80797180d;
    // Liquid Split (ETH Mainnet)
    address public constant LIQUID_SPLIT_FACTORY = 0xdEcd8B99b7F763e16141450DAa5EA414B7994831;
    address public constant LIQUID_SPLIT_MAIN = 0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE;

    uint256 public constant ARBITRATION_PRICE = 1000 * 10 ** 6; // 1000 USDC

    // IPAccounts
    mapping(address userAddr => mapping(MockERC721 nft => mapping(uint256 tokenId => address ipId))) internal ipacct;

    // NFT Token IDs List by User
    mapping(address userAddr => mapping(MockERC721 nft => uint256[] tokenIds)) internal token;

    // NFT Token IDs Set by User
    mapping(address userAddr => mapping(MockERC721 nft => EnumerableSet.UintSet tokenIdSet)) internal tokenSet;

    mapping(string frameworkName => uint256 frameworkId) internal frameworkIds;

    mapping(string policyName => uint256 policyId) internal policyIds;

    mapping(address userAddr => mapping(uint256 policyId => uint256 licenseId)) internal licenseIds;

    mapping(address userAddr => uint256 balance) internal mockTokenBalanceBefore;

    mapping(address userAddr => uint256 balance) internal mockTokenBalanceAfter;

    function setUp() public {
        ipacctImpl = new IPAccountImpl();
        ipacctRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(ipacctImpl)
        );
        licenseRegistry = new LicenseRegistry();

        disputeModule = new DisputeModule();
        arbitrationPolicySP = new ArbitrationPolicySP(address(disputeModule), USDC, ARBITRATION_PRICE);
        royaltyModule = new RoyaltyModule();
        royaltyPolicyLS = new RoyaltyPolicyLS(address(royaltyModule), LIQUID_SPLIT_FACTORY, LIQUID_SPLIT_MAIN);

        nft = MockERC721s({ a: new MockERC721("Mock"), b: new MockERC721("Mock"), c: new MockERC721("Mock") });
        u = UsersLib.createMockUsers(vm);

        royaltyModule.whitelistRoyaltyPolicy(address(royaltyPolicyLS), true);

        mockToken.mint(u.alice, 1000 * 10 ** mockToken.decimals());
        mockToken.mint(u.bob, 1000 * 10 ** mockToken.decimals());
        mockToken.mint(u.carl, 1000 * 10 ** mockToken.decimals());
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

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
        // assertTrue(ipId != address(0));
        assertEq(ipId, ipacctRegistry.ipAccount(block.chainid, address(mnft), tokenId));
    }

    function getIpId(address user, MockERC721 mnft, uint256 tokenId) public view returns (address ipId) {
        // require(mnft.ownerOf(tokenId) == user, "getIpId: not owner");
        ipId = ipacct[user][mnft][tokenId];
        require(ipId == ipacctRegistry.ipAccount(block.chainid, address(mnft), tokenId));
    }

    function test_Integration_helper_mintNFT() public {
        for (uint256 i = 1; i < 3; ++i) {
            assertEq(mintNFT(u.alice, nft.a), i);
            assertEq(mintNFT(u.bob, nft.b), i);
            assertEq(token[u.alice][nft.a].length, i);
            assertEq(token[u.bob][nft.b].length, i);
            assertEq(tokenSet[u.alice][nft.a].length(), i);
            assertEq(tokenSet[u.bob][nft.b].length(), i);
        }
        mintNFT(u.bob, nft.c);

        assertEq(token[u.alice][nft.a].length, 2);
        assertEq(token[u.bob][nft.b].length, 2);
        assertEq(token[u.bob][nft.c][0], 1);
        assertEq(tokenSet[u.alice][nft.a].length(), 2);
        assertEq(tokenSet[u.bob][nft.b].length(), 2);
        assertEq(tokenSet[u.bob][nft.c].length(), 1);
    }

    function test_Integration_helper_transferNFT() public {
        mintNFT(u.alice, nft.a);
        mintNFT(u.bob, nft.b);

        transferNFT(u.alice, u.bob, nft.a, 1);
        assertEq(token[u.alice][nft.a].length, 0);
        assertEq(token[u.alice][nft.b].length, 0);
        assertEq(token[u.bob][nft.a][0], 1);
        assertEq(token[u.bob][nft.b][0], 1);
        assertEq(tokenSet[u.alice][nft.a].length(), 0);
        assertEq(tokenSet[u.alice][nft.b].length(), 0);
        assertEq(tokenSet[u.bob][nft.a].length(), 1);
        assertEq(tokenSet[u.bob][nft.b].length(), 1);

        transferNFT(u.bob, u.alice, nft.b, 1);
        assertEq(token[u.alice][nft.a].length, 0);
        assertEq(token[u.alice][nft.b].length, 1);
        assertEq(token[u.bob][nft.a].length, 1);
        assertEq(token[u.bob][nft.b].length, 0);
        assertEq(token[u.bob][nft.a][0], 1);
        assertEq(tokenSet[u.alice][nft.a].length(), 0);
        assertEq(tokenSet[u.alice][nft.b].length(), 1);
        assertEq(tokenSet[u.bob][nft.a].length(), 1);
        assertEq(tokenSet[u.bob][nft.b].length(), 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    INTEGRATION
    //////////////////////////////////////////////////////////////////////////*/

    function test_Integration_Full() public {
        /*///////////////////////////////////////////////////////////////
                                CREATE IPACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        mintNFT(u.alice, nft.a); // nft a, id 1 (alice)
        mintNFT(u.bob, nft.a); // nft a, id 2 (bob)
        mintNFT(u.alice, nft.b); // nft b, id 1 (alice)
        mintNFT(u.carl, nft.c); // nft c, id 1 (carl)
        mintNFT(u.bob, nft.c); // nft c, id 2 (bob)

        registerIPAccount(u.alice, nft.a, token[u.alice][nft.a][0]);
        registerIPAccount(u.bob, nft.a, token[u.bob][nft.a][0]);
        registerIPAccount(u.carl, nft.c, token[u.carl][nft.c][0]);
        registerIPAccount(u.bob, nft.c, token[u.bob][nft.c][0]);

        /*///////////////////////////////////////////////////////////////
                            CREATE LICENSE FRAMEWORKS
        ////////////////////////////////////////////////////////////////*/

        MockPolicyFrameworkManager mock_lf_AllTrue = new MockPolicyFrameworkManager(
            MockPolicyFrameworkConfig({
                licenseRegistry: address(licenseRegistry),
                licenseUrl: "https://MockPolicyFrameworkManager.com/{id}.json",
                supportVerifyLink: true,
                supportVerifyMint: true,
                supportVerifyTransfer: true
            })
        );

        MintPaymentPolicyFrameworkManager mock_lf_MintPayment = new MintPaymentPolicyFrameworkManager(
            address(licenseRegistry),
            "https://expensive-minting-license.com/{id}.json",
            address(mockToken),
            1 * 10 ** mockToken.decimals()
        );

        frameworkIds["all_true"] = mock_lf_AllTrue.register();
        frameworkIds["mint_payment"] = mock_lf_MintPayment.register();

        // /*///////////////////////////////////////////////////////////////
        //                         CREATE POLICIES
        // ////////////////////////////////////////////////////////////////*/

        policyIds["test_true"] = mock_lf_AllTrue.addPolicy(
            MockPolicy({ returnVerifyLink: true, returnVerifyMint: true, returnVerifyTransfer: true })
        );

        policyIds["expensive_mint"] = mock_lf_MintPayment.addPolicy(MintPaymentPolicy({ mustBeTrue: true }));

        /*///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IPACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        licenseRegistry.addPolicyToIp(getIpId(u.alice, nft.a, 1), policyIds["test_true"]);
        licenseRegistry.addPolicyToIp(getIpId(u.carl, nft.c, 1), policyIds["expensive_mint"]);

        /*///////////////////////////////////////////////////////////////
                            MINT LICENSES ON POLICIES
        ////////////////////////////////////////////////////////////////*/

        // Carl mints 1 license for policy "test_true" on alice's NFT A IPAccount
        licenseIds[u.carl][policyIds["test_true"]] = licenseRegistry.mintLicense(
            policyIds["test_true"],
            getIpId(u.alice, nft.a, 1),
            1,
            u.carl
        );

        /*///////////////////////////////////////////////////////////////
                    LINK IPACCOUNTS TO PARENTS USING LICENSES
        ////////////////////////////////////////////////////////////////*/

        // Carl activates above license on his NFT C IPAccount, linking as child to Alice's NFT A IPAccount

        vm.prank(u.carl);
        licenseRegistry.linkIpToParent(licenseIds[u.carl][policyIds["test_true"]], getIpId(u.carl, nft.c, 1), u.carl);
        assertEq(licenseRegistry.balanceOf(u.carl, licenseIds[u.carl][policyIds["test_true"]]), 0, "not burnt");
        assertTrue(licenseRegistry.isParent(getIpId(u.alice, nft.a, 1), getIpId(u.carl, nft.c, 1)), "not parent");
        assertEq(
            keccak256(abi.encode(licenseRegistry.policyForIpAtIndex(getIpId(u.alice, nft.a, 1), 0))),
            keccak256(abi.encode(licenseRegistry.policyForIpAtIndex(getIpId(u.carl, nft.c, 1), 1))),
            // id 1, since Carl had a local policy before attaching Alice's policy
            "policy not copied"
        );

        // Bob mints 2 license for policy happy on Carl's NFT C IPAccount (inherits from Alice's NFT A IPAccount)
        // Bob will have to pay Carl 2 MockToken as Carl is using the expensive_mint policy, which uses
        // MintPaymentVerifier on mintingParam that checks for 2 MockToken payment
        vm.startPrank(u.bob); // need to prank twice for .decimals() and .approve()
        mockToken.approve(address(mock_lf_MintPayment), 2 * 10 ** mockToken.decimals());
        vm.stopPrank();

        // Bob mints 2 license for policy "expensive_mint" on carl's NFT C IPAccount

        mockTokenBalanceBefore[u.bob] = mockToken.balanceOf(u.bob);
        mockTokenBalanceBefore[address(mock_lf_MintPayment)] = mockToken.balanceOf(address(mock_lf_MintPayment));

        vm.startPrank(u.bob);
        licenseIds[u.bob][policyIds["expensive_mint"]] = licenseRegistry.mintLicense(
            policyIds["expensive_mint"],
            getIpId(u.carl, nft.c, 1), // licensorIpId
            2,
            u.bob
        );
        vm.stopPrank();

        mockTokenBalanceAfter[u.bob] = mockToken.balanceOf(u.bob);
        mockTokenBalanceAfter[address(mock_lf_MintPayment)] = mockToken.balanceOf(address(mock_lf_MintPayment));

        // Bob activates above license on his NFT A IPAccount, linking as child to Carl's NFT C IPAccount

        vm.prank(u.bob);
        licenseRegistry.linkIpToParent(licenseIds[u.bob][policyIds["expensive_mint"]], getIpId(u.bob, nft.a, 2), u.bob);

        assertEq(
            licenseRegistry.balanceOf(u.bob, licenseIds[u.bob][policyIds["expensive_mint"]]),
            1, // 1 left
            "not burnt"
        );
        assertTrue(licenseRegistry.isParent(getIpId(u.carl, nft.c, 1), getIpId(u.bob, nft.a, 2)), "not parent");
        assertEq(
            keccak256(abi.encode(licenseRegistry.policyForIpAtIndex(getIpId(u.carl, nft.c, 1), 0))),
            keccak256(abi.encode(licenseRegistry.policyForIpAtIndex(getIpId(u.bob, nft.a, 2), 0))),
            "policy not copied"
        );

        assertEq(
            mockTokenBalanceBefore[u.bob] - mockTokenBalanceAfter[u.bob],
            2 * mock_lf_MintPayment.payment(),
            "Bob didn't pay Carl"
        );
        assertEq(
            mockTokenBalanceAfter[address(mock_lf_MintPayment)] - mockTokenBalanceBefore[address(mock_lf_MintPayment)],
            2 * mock_lf_MintPayment.payment(),
            "Carl didn't receive payment"
        );
    }
}
