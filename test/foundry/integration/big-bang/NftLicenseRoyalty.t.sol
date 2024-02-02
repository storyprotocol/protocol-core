// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// contract
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { ILiquidSplitClone } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicyLS } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLS.sol";
import { ILSClaimer } from "contracts/interfaces/modules/royalty/policies/ILSClaimer.sol";
import { IP } from "contracts/lib/IP.sol";
import { LSClaimer } from "contracts/modules/royalty-module/policies/LSClaimer.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.sol";
import { MintPaymentPolicyFrameworkManager } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { Integration_Shared_LicensingHelper, UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/integration/shared/LicenseHelper.sol";

contract BigBang_Integration_NftLicenseRoyalty is BaseIntegration, Integration_Shared_LicensingHelper {
    using EnumerableSet for EnumerableSet.UintSet;

    // TODO: import from ILiquidSplitMain in 0xSplits
    event DistributeERC20(address split, address token, uint256 amount, address distributorAddress);

    MockERC721 internal nft;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    mapping(string name => uint256 licenseId) internal licenseIds;

    uint32 internal constant minRevShare = 250; // 25%

    function setUp() public override {
        BaseIntegration.setUp();
        Integration_Shared_LicensingHelper.initLicenseFrameworkAndPolicy(
            accessController,
            licenseRegistry,
            royaltyModule
        );

        nft = erc721.cat;

        nft.mintId(u.alice, 1);
        nft.mintId(u.bob, 2);
        nft.mintId(u.carl, 3);
        nft.mintId(u.dan, 4);
    }

    function test_Integration_NftLicenseRoyalty_SingleChain()
        public
        withLFM_UML
        withUMLPolicy_Commerical_Derivative(
            UMLPolicyGenericParams({
                policyName: "reciprocal", // => uml_com_deriv_reciprocal
                attribution: false,
                transferable: false,
                territories: new string[](0),
                distributionChannels: new string[](0)
            }),
            UMLPolicyCommercialParams({
                commercialAttribution: true,
                commercializers: new string[](0),
                commercialRevShare: minRevShare,
                royaltyPolicy: address(royaltyPolicyLS)
            }),
            UMLPolicyDerivativeParams({
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true, // ==> reciprocal
                derivativesRevShare: minRevShare
            })
        )
    {
        /*///////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        // Alice registers NFT 1 IPAccount

        vm.startPrank(u.alice);
        ipAcct[1] = registerIpAccount(nft, 1, u.alice);

        //
        // NOTE: This 150 overrides UML's `derivativesRevShare` of 250, when used below in `setRoyaltyPolicy`.
        //       But the derivatives will have the 250. Is this possible in reciprocal license (specifid above)?
        //       The derivatives are inheriting all traits, including `derivativesRevShare = 250`, which is
        //       different from ipAcct[1] due to the custom `minRevShareIpAcct1` set below.
        //
        uint32 minRevShareIpAcct1 = 150; // 15%

        // Alice sets royalty policy on her root IP
        {
            royaltyModule.setRoyaltyPolicy(
                ipAcct[1],
                address(royaltyPolicyLS),
                new address[](0), // no parent
                abi.encode(minRevShareIpAcct1)
            );
        }

        /*///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IP ACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        // Alice attaches the UML Commercial Derivative Reciprocal policy to NFT 1 IPAccount

        vm.startPrank(u.alice);
        licenseRegistry.addPolicyToIp(ipAcct[1], policyIds["uml_com_deriv_reciprocal"]);

        /*///////////////////////////////////////////////////////////////
                                MINT & USE LICENSES
        ////////////////////////////////////////////////////////////////*/

        // Bob mints 1 license from Alice's NFT 1 IPAccount, registers NFT 2 IPAccount, and links using the license
        {
            vm.startPrank(u.bob);
            uint256 bob_license_from_root_alice = licenseRegistry.mintLicense(
                policyIds["uml_com_deriv_reciprocal"],
                ipAcct[1], // Alice's IPAccount
                1,
                u.bob
            );

            ipAcct[2] = registerIpAccount(nft, 2, u.bob);
            linkIpToParent(bob_license_from_root_alice, ipAcct[2], u.bob);

            (, , , uint256 minRoyalty) = royaltyPolicyLS.royaltyData(ipAcct[2]);
            assertEq(minRoyalty, minRevShare);
        }

        // Carl mints 1 license from Bob's NFT 2 IPAccount, registers NFT 3 IPAccount, and links using the license
        {
            vm.startPrank(u.carl);
            uint256 carl_license_from_bob = licenseRegistry.mintLicense(
                policyIds["uml_com_deriv_reciprocal"],
                ipAcct[2], // Bob's IPAccount
                1,
                u.carl
            );

            ipAcct[3] = registerDerivativeIp(
                carl_license_from_bob,
                address(nft),
                3,
                IP.MetadataV1({
                    name: "IP NAME",
                    hash: bytes32("hash"),
                    registrationDate: uint64(block.timestamp),
                    registrant: u.carl, // caller
                    uri: "external URL"
                }),
                u.carl // caller
            );

            (, , , uint256 minRoyalty) = royaltyPolicyLS.royaltyData(ipAcct[3]);
            assertEq(minRoyalty, minRevShare);
        }

        // Dan mints 1 license from Carl's NFT 3 IPAccount, registers NFT 4 IPAccount, and links using the license
        {
            vm.startPrank(u.dan);
            uint256 dan_license_from_carl = licenseRegistry.mintLicense(
                policyIds["uml_com_deriv_reciprocal"],
                ipAcct[3], // Carl's IPAccount
                1,
                u.dan
            );

            ipAcct[4] = registerDerivativeIp(
                dan_license_from_carl,
                address(nft),
                4,
                IP.MetadataV1({
                    name: "IP NAME",
                    hash: bytes32("hash"),
                    registrationDate: uint64(block.timestamp),
                    registrant: u.dan, // caller
                    uri: "external URL"
                }),
                u.dan // caller
            );

            (, , , uint256 minRoyalty) = royaltyPolicyLS.royaltyData(ipAcct[4]);
            assertEq(minRoyalty, minRevShare);
        }

        uint256 royaltyAmount = 1000 * 10 ** 6; // 1000 USDC

        // Dan gets paid by Alice for his NFT 4 IPAccount
        {
            vm.startPrank(u.alice);
            address ipAcct_Alice = ipAcct[1];
            address ipAcct_Dan = ipAcct[4];

            USDC.approve(address(royaltyPolicyLS), royaltyAmount);

            (address danSplitClone, address danClaimer, , ) = royaltyPolicyLS.royaltyData(ipAcct_Dan);

            vm.expectEmit(address(USDC));
            emit IERC20.Transfer(u.alice, address(danSplitClone), royaltyAmount); // destination of payment

            vm.expectEmit(address(royaltyModule));
            emit IRoyaltyModule.RoyaltyPaid(ipAcct_Dan, ipAcct_Alice, u.alice, address(USDC), royaltyAmount);

            royaltyModule.payRoyaltyOnBehalf(ipAcct_Dan, ipAcct_Alice, address(USDC), royaltyAmount);

            assertEq(USDC.balanceOf(danSplitClone), royaltyAmount);
        }

        // Distribute the accrued revenue from the 0xSplitWallet associated with Dan's IPAccount to
        // 0xSplits Main, which will get distributed to Dan's IPAccount AND Dan's claimer based on revenue
        // sharing terms specified in royalty policy.
        {
            vm.startPrank(u.dan);

            address ipAcct_Alice = ipAcct[1];
            address ipAcct_Dan = ipAcct[4];
            (, address danClaimer, , ) = royaltyPolicyLS.royaltyData(ipAcct_Dan);

            address[] memory accounts = new address[](2);
            // order matters, otherwise error: InvalidSplit__AccountsOutOfOrder
            accounts[0] = ipAcct_Dan;
            accounts[1] = danClaimer;

            // TODO: check events
            // NOTE: need to use assertApproxEqRel(left, right, 0.0001e18) since decimal calc loses precision oddly
            // MockUSDC::transfer -> Transfer
            // LIQUID_SPLIT_MAIN::updateAndDistributeERC20 -> UpdateSplit & DistributeERC20 & (MockUSDC) Transfer
            royaltyPolicyLS.distributeFunds(ipAcct_Dan, address(USDC), accounts, address(0));
        }

        // Alice claims her rNFTs and tokens, only done once since it's a single chain
        {
            vm.startPrank(u.alice);

            address ipAcct_Alice = ipAcct[1];
            address ipAcct_Dan = ipAcct[4];
            (address aliceSplitClone, , , ) = royaltyPolicyLS.royaltyData(ipAcct_Alice);
            (address danSplitClone, address danClaimer, , ) = royaltyPolicyLS.royaltyData(ipAcct_Dan);

            address[] memory chain_alice_to_dan = new address[](4);
            chain_alice_to_dan[0] = ipAcct[1];
            chain_alice_to_dan[1] = ipAcct[2];
            chain_alice_to_dan[2] = ipAcct[3];
            chain_alice_to_dan[3] = ipAcct[4];

            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = ERC20(USDC);

            // Alice calls on behalf of Dan's claimer to send money from the Split Main to Dan's claimer,
            // since the revenue payment was made to Dan's Split Wallet, which got distributed to the claimer.

            // Dan is paying 65% of 1000 USDC royalty to parents (stored in Dan's Claimer).
            // The other 35% of 1000 USDC royalty goes directly to Dan's IPAccount.
            vm.expectEmit(address(USDC));
            emit IERC20.Transfer(LIQUID_SPLIT_MAIN, address(danClaimer), 649999998);
            royaltyPolicyLS.claimRoyalties({ _account: danClaimer, _withdrawETH: 0, _tokens: tokens });

            // Alice calls the claim her portion of rNFTs and tokens. She can only call `claim` once.
            // Afterwards, she will automatically receive money on revenue distribution.

            vm.expectEmit(address(danSplitClone));
            emit IERC1155.TransferSingle({ // rNFTs
                operator: address(danClaimer),
                from: address(danClaimer),
                to: aliceSplitClone,
                id: 0,
                value: minRevShareIpAcct1
            });

            vm.expectEmit(address(USDC));
            emit IERC20.Transfer(address(danClaimer), aliceSplitClone, 149999999); // alice should get 15% of 1000 USDC

            vm.expectEmit(address(danClaimer));
            emit ILSClaimer.Claimed({
                path: chain_alice_to_dan,
                claimer: ipAcct_Alice,
                withdrawETH: false,
                tokens: tokens
            });

            LSClaimer(danClaimer).claim({
                _path: chain_alice_to_dan,
                _claimerIpId: ipAcct_Alice,
                _withdrawETH: false,
                _tokens: tokens
            });
        }
    }
}
