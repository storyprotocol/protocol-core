// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// contract
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.sol";
import { MintPaymentPolicyFrameworkManager } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { Integration_Shared_LicenseFramework_and_Policy, UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/integration/shared/LicenseFrameworkPolicy.sol";

contract BigBang_Integration_SingleNftCollection is BaseIntegration, Integration_Shared_LicenseFramework_and_Policy {
    using EnumerableSet for EnumerableSet.UintSet;

    MockERC721 internal nft;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    mapping(string name => uint256 licenseId) internal licenseIds;

    function setUp() public override {
        BaseIntegration.setUp();
        Integration_Shared_LicenseFramework_and_Policy.initLicenseFrameworkAndPolicy(accessController, licenseRegistry);

        nft = erc721.cat;

        nft.mintId(u.alice, 1);
        nft.mintId(u.alice, 2);
        nft.mintId(u.bob, 3);
        nft.mintId(u.bob, 4);
        nft.mintId(u.carl, 5);
        nft.mintId(u.carl, 6);
    }

    function test_Integration_SingleNftCollection_DirectCallsByIPAccountOwners()
        public
        withLFM_UML
        withLFM_MintPayment(erc20, 1)
        withUMLPolicy_Commerical_Derivative(
            UMLPolicyGenericParams({
                policyName: "cheap_flexible", // => com_deriv_cheap_flexible
                attribution: false,
                transferable: true,
                territories: new string[](0),
                distributionChannels: new string[](0)
            }),
            UMLPolicyCommercialParams({
                commercialAttribution: true,
                commercializers: new string[](0),
                commercialRevShare: 10
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
                policyName: "reciprocal_derivative", // => noncom_deriv_reciprocal_derivative
                attribution: false,
                transferable: true,
                territories: new string[](0),
                distributionChannels: new string[](0)
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
                policyName: "self", // => noncom_nonderiv_self
                attribution: false,
                transferable: false,
                territories: new string[](0),
                distributionChannels: new string[](0)
            })
        )
    {
        /*///////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        // ipAcct[tokenId] => ipAccount address
        // owner is the vm.pranker

        vm.startPrank(u.alice);
        ipAcct[1] = registerIpAccount(nft, 1);

        vm.startPrank(u.bob);
        ipAcct[3] = registerIpAccount(nft, 3);

        vm.startPrank(u.carl);
        ipAcct[5] = registerIpAccount(nft, 5);

        /*///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IP ACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        vm.startPrank(u.alice);
        licenseRegistry.addPolicyToIp(ipAcct[1], policyIds["uml_com_deriv_cheap_flexible"]);

        vm.startPrank(u.bob);
        // NOTE: the below two achieve the same functionality, however the commented out method fails.
        // First approach succeeds:
        licenseRegistry.addPolicyToIp(ipAcct[3], policyIds["uml_noncom_deriv_reciprocal_derivative"]);
        // Second approach's flow is:
        // 1. IPAccount.execute calls `AcessController.checkPermission()`
        // 1a. -> checkPermission returns true
        // 2. IPAccount calls `LicenseRegistry.addPolicyToIp()`
        // 2a. -> calls checkPermission with param data as (IPAccount, IPAccount, LicenseRegistry, fn selector)
        // 2b. -> returns false, inside the if (functionPermission == AccessPermission.ABSTAIN) branch
        // -> ERROR LicenseRegistry__UnauthorizedAccess
        // IIPAccount(payable(ipAcct[3])).execute(
        //     address(licenseRegistry),
        //     0,
        //     abi.encodeWithSignature(
        //         "addPolicyToIp(address,uint256)",
        //         ipAcct[3],
        //         policyIds["uml_noncom_deriv_reciprocal_derivative"]
        //     )
        // );

        /*///////////////////////////////////////////////////////////////
                                MINT & USE LICENSES
        ////////////////////////////////////////////////////////////////*/

        // Carl mints 1 license for policy "com_deriv_all_true" on Alice's NFT 1 IPAccount
        // Carl creates NFT 6 IPAccount
        // Carl activates the license on his NFT 6 IPAccount, linking as child to Alice's NFT 1 IPAccount
        {
            vm.startPrank(u.carl);
            uint256 carl_license_from_root_alice = licenseRegistry.mintLicense(
                policyIds["uml_com_deriv_cheap_flexible"],
                ipAcct[1],
                1,
                u.carl
            );

            ipAcct[6] = registerIpAccount(nft, 6);
            linkIpToParent(carl_license_from_root_alice, ipAcct[6], u.carl);
        }

        // Alice mints 2 license for policy "noncom_deriv_mint_payment" on Bob's NFT 3 IPAccount
        // Alice creates NFT 2 IPAccount
        // Alice activates one of the two licenses on her NFT 2 IPAccount, linking as child to Bob's NFT 3 IPAccount
        // Alice creates derivative NFT 3 directly using the other license
        // NOTE: since this policy has `MintPaymentPolicyFrameworkManager` attached, Alice must pay the mint payment
        {
            vm.startPrank(u.alice);
            uint256 mintAmount = 2;

            erc20.approve(
                pfm["mint_payment"].addr,
                mintAmount * MintPaymentPolicyFrameworkManager(pfm["mint_payment"].addr).payment()
            );

            uint256 alice_license_from_root_bob = licenseRegistry.mintLicense(
                policyIds["uml_noncom_deriv_reciprocal_derivative"],
                ipAcct[3],
                2,
                u.alice
            );

            ipAcct[2] = registerIpAccount(nft, 2);
            linkIpToParent(alice_license_from_root_bob, ipAcct[2], u.alice);

            uint256 tokenId = 99999999;
            nft.mintId(u.alice, tokenId);

            //
            // ERROR: this ALSO fails with `LicenseRegistry__UnauthorizedAccess`,
            // in `LicenseRegistry.linkIpToParent()` step after `IPRecordRegistry.register()`
            //
            // FLOW:
            // 1. RegistrationModule calls `IPRecordRegistry.register()`
            // 1a. -> no checkPermission check, succeeds
            // 2. RegistrationModule calls `IPMetadataProvider.setMetadata()`
            // 2a. -> suceeds
            // 3. RegistrationModule calls `LicenseRegistry.linkToParent()`
            // 3a. -> calls checkPermission with param data as (IPAccount, IPAccount, LicenseRegistry, fn selector)
            // 3b. -> returns false, inside the if (functionPermission == AccessPermission.ABSTAIN) branch
            // -> ERROR LicenseRegistry__UnauthorizedAccess
            //
            ipAcct[tokenId] = registerDerivativeIp(
                alice_license_from_root_bob,
                address(nft),
                tokenId,
                "IP NAME",
                bytes32("hash"),
                "external URL",
                u.alice
            );
        }

        // Bob tags Alice's NFT
        {
            vm.startPrank(u.bob);
            taggingModule.setTag("sequel", ipAcct[99999999]);
            assertTrue(taggingModule.isTagged("sequel", ipAcct[99999999]));
        }
    }
}
