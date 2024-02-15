/* // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// contract
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { ILSClaimer } from "contracts/interfaces/modules/royalty/policies/ILSClaimer.sol";
import { IP } from "contracts/lib/IP.sol";
import { LSClaimer } from "contracts/modules/royalty-module/policies/LSClaimer.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.t.sol";
// solhint-disable-next-line max-line-length
import { UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/utils/LicensingHelper.t.sol";

contract BigBang_Integration_NftLicenseRoyalty is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;

    // TODO: import from ILiquidSplitMain in 0xSplits
    event DistributeERC20(address split, address token, uint256 amount, address distributorAddress);

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    mapping(string name => uint256 licenseId) internal licenseIds;

    uint32 internal constant minRevShare = 250; // 25%

    function setUp() public override {
        BaseIntegration.setUp();

        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);
        mockNFT.mintId(u.carl, 3);
        mockNFT.mintId(u.dan, 4);
    }

    function test_Integration_NftLicenseRoyalty_SingleChain()
        public
        withLFM_UML
        withUMLPolicy_Commercial_Derivative(
            UMLPolicyGenericParams({
                policyName: "reciprocal", // => uml_com_deriv_reciprocal
                attribution: false,
                transferable: false,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            }),
            UMLPolicyCommercialParams({
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
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
        ///////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ////////////////////////////////////////////////////////////////

        // Alice registers NFT 1 IPAccount

        vm.startPrank(u.alice);
        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);

        ///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IP ACCOUNTS
        ////////////////////////////////////////////////////////////////

        // Alice attaches the UML Commercial Derivative Reciprocal policy to NFT 1 IPAccount

        vm.startPrank(u.alice);
        licensingModule.addPolicyToIp(ipAcct[1], policyIds["uml_com_deriv_reciprocal"]);

        ///////////////////////////////////////////////////////////////
                                MINT & USE LICENSES
        ////////////////////////////////////////////////////////////////

        // Bob mints 1 license from Alice's NFT 1 IPAccount, registers NFT 2 IPAccount, and links using the license
        {
            vm.startPrank(u.bob);
            uint256 bob_license_from_root_alice = licensingModule.mintLicense(
                policyIds["uml_com_deriv_reciprocal"],
                ipAcct[1], // Alice's IPAccount
                1,
                u.bob
            );

            ipAcct[2] = registerIpAccount(mockNFT, 2, u.bob);
            linkIpToParent(bob_license_from_root_alice, ipAcct[2], u.bob, 0);

            (, , , uint256 minRoyalty) = royaltyPolicyLS.royaltyData(ipAcct[2]);
            assertEq(minRoyalty, minRevShare);
        }

        // Carl mints 1 license from Bob's NFT 2 IPAccount, registers NFT 3 IPAccount, and links using the license
        {
            vm.startPrank(u.carl);
            uint256 carl_license_from_bob = licensingModule.mintLicense(
                policyIds["uml_com_deriv_reciprocal"],
                ipAcct[2], // Bob's IPAccount
                1,
                u.carl
            );

            ipAcct[3] = registerDerivativeIp(
                carl_license_from_bob,
                address(mockNFT),
                3,
                IP.MetadataV1({
                    name: "IP NAME",
                    hash: bytes32("hash"),
                    registrationDate: uint64(block.timestamp),
                    registrant: u.carl, // caller
                    uri: "external URL"
                }),
                u.carl, // caller
                0 // gets overriden by license
            );

            (, , , uint256 minRoyalty) = royaltyPolicyLS.royaltyData(ipAcct[3]);
            assertEq(minRoyalty, minRevShare);
        }

        // Dan mints 1 license from Carl's NFT 3 IPAccount, registers NFT 4 IPAccount, and links using the license
        {
            vm.startPrank(u.dan);
            uint256 dan_license_from_carl = licensingModule.mintLicense(
                policyIds["uml_com_deriv_reciprocal"],
                ipAcct[3], // Carl's IPAccount
                1,
                u.dan
            );

            ipAcct[4] = registerDerivativeIp(
                dan_license_from_carl,
                address(mockNFT),
                4,
                IP.MetadataV1({
                    name: "IP NAME",
                    hash: bytes32("hash"),
                    registrationDate: uint64(block.timestamp),
                    registrant: u.dan, // caller
                    uri: "external URL"
                }),
                u.dan, // caller
                0 // gets overriden by license
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

            (address danSplitClone, , , ) = royaltyPolicyLS.royaltyData(ipAcct_Dan);

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

            address ipAcct_Dan = ipAcct[4];
            (, address danClaimer, , ) = royaltyPolicyLS.royaltyData(ipAcct_Dan);

            address[] memory accounts = new address[](2);
            // order matters, otherwise error: InvalidSplit__AccountsOutOfOrder
            accounts[1] = ipAcct_Dan;
            accounts[0] = danClaimer;

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
            emit IERC20.Transfer(LIQUID_SPLIT_MAIN, address(danClaimer), 749999998);
            royaltyPolicyLS.claimRoyalties({ _account: danClaimer, _withdrawETH: 0, _tokens: tokens });

            // Alice calls the claim her portion of rNFTs and tokens. She can only call `claim` once.
            // Afterwards, she will automatically receive money on revenue distribution.

            vm.expectEmit(address(danSplitClone));
            emit IERC1155.TransferSingle({ // rNFTs
                    operator: address(danClaimer),
                    from: address(danClaimer),
                    to: aliceSplitClone,
                    id: 0,
                    value: 250
                });

            vm.expectEmit(address(USDC));
            emit IERC20.Transfer(address(danClaimer), aliceSplitClone, 249999999); // alice should get 25% of 1000 USDC

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
 */