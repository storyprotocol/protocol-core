// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// contract
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IP } from "contracts/lib/IP.sol";
import { Errors } from "contracts/lib/Errors.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.t.sol";
import { MintPaymentPolicyFrameworkManager } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";
// solhint-disable-next-line max-line-length
import { UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/utils/LicensingHelper.t.sol";

contract BigBang_Integration_SingleNftCollection is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    mapping(string name => uint256 licenseId) internal licenseIds;

    function setUp() public override {
        super.setUp();
    }

    function test_Integration_SingleNftCollection_DirectCallsByIPAccountOwners()
        public
        withLFM_UML
        withLFM_MintPayment(erc20, 1)
        withUMLPolicy_Commercial_Derivative(
            UMLPolicyGenericParams({
                policyName: "cheap_flexible", // => uml_com_deriv_cheap_flexible
                attribution: false,
                transferable: true,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            }),
            UMLPolicyCommercialParams({
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 10,
                royaltyPolicy: address(royaltyPolicyLS)
            }),
            UMLPolicyDerivativeParams({
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: false,
                derivativesRevShare: 10
            })
        )
        withUMLPolicy_NonCommercial_Derivative(
            UMLPolicyGenericParams({
                policyName: "reciprocal_derivative", // => uml_noncom_derive_reciprocal_derivative
                attribution: false,
                transferable: true,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            }),
            UMLPolicyDerivativeParams({
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                derivativesRevShare: 0 // non-commercial => no rev share
            })
        )
        withUMLPolicy_NonCommercial_NonDerivative(
            UMLPolicyGenericParams({
                policyName: "self", // => uml_noncom_nonderiv_self
                attribution: false,
                transferable: false,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            })
        )
        withMintPaymentPolicy("normal", true) // => mint_payment_normal
        withMintPaymentPolicy("fail", false) // => mint_payment_fail (always returns false even if payment is made)
    {
        /*///////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        // ipAcct[tokenId] => ipAccount address
        // owner is the vm.pranker

        vm.startPrank(u.alice);
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.alice, 100);
        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
        ipAcct[100] = registerIpAccount(mockNFT, 100, u.alice);

        vm.startPrank(u.bob);
        mockNFT.mintId(u.bob, 3);
        mockNFT.mintId(u.bob, 300);
        ipAcct[3] = registerIpAccount(mockNFT, 3, u.bob);
        ipAcct[300] = registerIpAccount(mockNFT, 300, u.bob);

        vm.startPrank(u.carl);
        mockNFT.mintId(u.carl, 5);
        ipAcct[5] = registerIpAccount(mockNFT, 5, u.carl);

        /*///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IP ACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        vm.startPrank(u.alice);
        licensingModule.addPolicyToIp(ipAcct[1], policyIds["uml_com_deriv_cheap_flexible"]);
        licensingModule.addPolicyToIp(ipAcct[100], policyIds["uml_noncom_deriv_reciprocal_derivative"]);

        // Alice sets royalty policy for her root IPAccounts
        // (so other IPAccounts can use her policies that inits royalty policy on linking)
        // TODO: setRoyaltyPolicy should be called through mintLicense or addPolicyToIp, not directly by user
        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(
            ipAcct[1],
            address(royaltyPolicyLS),
            new address[](0), // no parent
            abi.encode(10)
        );

        vm.startPrank(u.bob);
        // For the next addPolicyToIp, we set policy to be true for commercial in this mock PFM.
        MintPaymentPolicyFrameworkManager(pfm["mint_payment"]).setPolicyCommercial(
            policyIds["mint_payment_normal"],
            true
        );
        licensingModule.addPolicyToIp(ipAcct[3], policyIds["mint_payment_normal"]);
        licensingModule.addPolicyToIp(ipAcct[300], policyIds["uml_com_deriv_cheap_flexible"]);

        // Bob sets royalty policy for his root IPAccounts
        // (so other IPAccounts can use his policies that inits royalty policy on linking)
        // TODO: setRoyaltyPolicy should be called through mintLicense or addPolicyToIp, not directly by user
        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(
            ipAcct[300],
            address(royaltyPolicyLS),
            new address[](0), // no parent
            abi.encode(10)
        );

        vm.startPrank(u.bob);
        // NOTE: the two calls below achieve the same functionality
        // licensingModule.addPolicyToIp(ipAcct[3], policyIds["uml_noncom_deriv_reciprocal_derivative"]);
        IIPAccount(payable(ipAcct[3])).execute(
            address(licensingModule),
            0,
            abi.encodeWithSignature(
                "addPolicyToIp(address,uint256)",
                ipAcct[3],
                policyIds["uml_noncom_deriv_reciprocal_derivative"]
            )
        );

        /*///////////////////////////////////////////////////////////////
                                MINT & USE LICENSES
        ////////////////////////////////////////////////////////////////*/

        // Carl mints 1 license for policy "com_deriv_all_true" on Alice's NFT 1 IPAccount
        // Carl creates NFT 6 IPAccount
        // Carl activates the license on his NFT 6 IPAccount, linking as child to Alice's NFT 1 IPAccount
        {
            vm.startPrank(u.carl);
            mockNFT.mintId(u.carl, 6);
            uint256[] memory carl_license_from_root_alice = new uint256[](1);
            carl_license_from_root_alice[0] = licensingModule.mintLicense(
                policyIds["uml_com_deriv_cheap_flexible"],
                ipAcct[1],
                1,
                u.carl
            );

            ipAcct[6] = registerIpAccount(mockNFT, 6, u.carl);
            // minRoyalty = 0 gets overridden by the `derivativesRevShare` value of the linking licenses
            linkIpToParents(carl_license_from_root_alice, ipAcct[6], u.carl, 0);
        }

        // Carl mints 2 license for policy "uml_noncom_deriv_reciprocal_derivative" on Bob's NFT 3 IPAccount
        // Carl creates NFT 7 IPAccount
        // Carl activates one of the two licenses on his NFT 7 IPAccount, linking as child to Bob's NFT 3 IPAccount
        {
            vm.startPrank(u.carl);
            mockNFT.mintId(u.carl, 7);
            uint256[] memory carl_license_from_root_bob = new uint256[](1);
            carl_license_from_root_bob[0] = licensingModule.mintLicense(
                policyIds["uml_noncom_deriv_reciprocal_derivative"],
                ipAcct[3],
                1,
                u.carl
            );

            ipAcct[7] = registerIpAccount(mockNFT, 7, u.carl);
            // minRoyalty = 0 gets overridden by the `derivativesRevShare` value of the linking licenses
            linkIpToParents(carl_license_from_root_bob, ipAcct[7], u.carl, 0);
        }

        // Alice mints 2 license for policy "mint_payment_normal" on Bob's NFT 3 IPAccount
        // Alice creates NFT 2 IPAccount
        // Alice activates one of the two licenses on her NFT 2 IPAccount, linking as child to Bob's NFT 3 IPAccount
        // Alice creates derivative NFT 3 directly using the other license
        // NOTE: since this policy has `MintPaymentPolicyFrameworkManager` attached, Alice must pay the mint payment
        {
            vm.startPrank(u.alice);
            mockNFT.mintId(u.alice, 2);
            uint256 mintAmount = 2;
            uint256 paymentPerMint = MintPaymentPolicyFrameworkManager(pfm["mint_payment"]).payment();

            erc20.approve(pfm["mint_payment"], mintAmount * paymentPerMint);

            uint256 aliceTokenBalance = erc20.balanceOf(u.alice);
            uint256 pfmTokenBalance = erc20.balanceOf(pfm["mint_payment"]);

            mockRoyaltyPolicyLS.setMinRoyalty(ipAcct[3], 0);

            uint256[] memory alice_license_from_root_bob = new uint256[](1);
            alice_license_from_root_bob[0] = licensingModule.mintLicense(
                policyIds["mint_payment_normal"],
                ipAcct[3],
                mintAmount,
                u.alice
            );

            assertEq(
                aliceTokenBalance - erc20.balanceOf(u.alice),
                mintAmount * paymentPerMint,
                "Alice didn't pay to PolicyFrameworkManager"
            );
            assertEq(
                erc20.balanceOf(pfm["mint_payment"]) - pfmTokenBalance,
                mintAmount * paymentPerMint,
                "MintPaymentPolicyFrameworkManager didn't receive payment"
            );

            ipAcct[2] = registerIpAccount(mockNFT, 2, u.alice);
            linkIpToParents(alice_license_from_root_bob, ipAcct[2], u.alice, 0);

            uint256 tokenId = 99999999;
            mockNFT.mintId(u.alice, tokenId);

            ipAcct[tokenId] = registerDerivativeIps(
                alice_license_from_root_bob,
                address(mockNFT),
                tokenId,
                IP.MetadataV1({
                    name: "IP NAME",
                    hash: bytes32("hash"),
                    registrationDate: uint64(block.timestamp),
                    registrant: u.alice, // caller
                    uri: "external URL"
                }),
                u.alice, // caller
                0
            );
        }

        // Bob tags Alice's NFT
        {
            vm.startPrank(u.bob);
            taggingModule.setTag("sequel", ipAcct[99999999]);
            assertTrue(taggingModule.isTagged("sequel", ipAcct[99999999]));
        }

        // Carl mints licenses and linkts to multiple parents
        // Carl creates NFT 6 IPAccount
        // Carl activates the license on his NFT 6 IPAccount, linking as child to Alice's NFT 1 IPAccount
        {
            vm.startPrank(u.carl);

            uint256 tokenId = 70000; // dummy number that shouldn't conflict with any other token IDs used in this test
            mockNFT.mintId(u.carl, tokenId);

            uint256 paymentPerMint = MintPaymentPolicyFrameworkManager(pfm["mint_payment"]).payment();

            IP.MetadataV1 memory metadata = IP.MetadataV1({
                name: "IP NAME",
                hash: bytes32("hash"),
                registrationDate: uint64(block.timestamp),
                registrant: u.carl, // caller
                uri: "external URL"
            });

            erc20.approve(pfm["mint_payment"], 1 * paymentPerMint);

            uint256[] memory carl_licenses = new uint256[](2);
            // Commercial license
            carl_licenses[0] = licensingModule.mintLicense(
                policyIds["uml_com_deriv_cheap_flexible"], // ipAcct[1] has this policy attached
                ipAcct[1],
                100, // mint 100 licenses
                u.carl
            );

            // Non-commercial license
            carl_licenses[1] = licensingModule.mintLicense(
                policyIds["uml_noncom_deriv_reciprocal_derivative"], // ipAcct[3] has this policy attached
                ipAcct[3],
                1,
                u.carl
            );

            // This should revert since license[0] is commercial but license[1] is non-commercial
            vm.expectRevert(Errors.LicensingModule__IncompatibleLicensorCommercialPolicy.selector);
            // Call `registrationModule.registerDerivativeIps` directly because expecting revert on the
            // wrapper `registerDerivativeIps` fails due to the implementation of the wrapper function.
            registrationModule.registerDerivativeIp(
                carl_licenses,
                address(mockNFT),
                tokenId,
                metadata.name,
                metadata.hash,
                metadata.uri,
                10
            );

            // Modify license[1] to a Commercial license
            carl_licenses[1] = licensingModule.mintLicense(
                policyIds["uml_com_deriv_cheap_flexible"], // ipAcct[300] has this policy attached
                ipAcct[300],
                1,
                u.carl
            );

            // This should succeed since both license[0] and license[1] are commercial
            registerDerivativeIps(
                carl_licenses, // ipAcct[1] and ipAcct[3] licenses
                address(mockNFT),
                tokenId,
                metadata,
                u.carl, // caller
                0 // gets overridden by the `derivativesRevShare` value of the linking licenses
            );
        }
    }
}
