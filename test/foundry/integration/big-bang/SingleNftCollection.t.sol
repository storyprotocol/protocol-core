// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// contract

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.sol";
import { Integration_Shared_LicenseFramework_and_Policy, PolicyModifierParams } from "test/foundry/integration/shared/LicenseFrameworkPolicy.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

contract BigBang_Integration_SingleNftCollection is BaseIntegration, Integration_Shared_LicenseFramework_and_Policy {
    using EnumerableSet for EnumerableSet.UintSet;

    MockERC721 internal nft;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    function setUp() public override {
        BaseIntegration.setUp();
        Integration_Shared_LicenseFramework_and_Policy.initLicenseFrameworkAndPolicy(licenseRegistry);

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
        withLicenseFramework_Truthy("all_true", address(verifier.onAll))
        withLicenseFramework_Truthy("mint_payment", address(verifier.mintPayment))
        withPolicy_Commerical_Derivative(_policyParams_Truthy("all_true", address(verifier.onAll)))
        withPolicy_NonCommerical_Derivative(_policyParams_Truthy("mint_payment", address(verifier.mintPayment)))
    {
        /*///////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        vm.startPrank(u.alice);
        ipAcct[1] = registerIpAccount(nft, 1);

        vm.startPrank(u.bob);
        ipAcct[3] = registerIpAccount(nft, 3);

        vm.startPrank(u.carl);
        ipAcct[5] = registerIpAccount(nft, 5);

        /*///////////////////////////////////////////////////////////////
                            ADD POLICIES TO IP ACCOUNTS
        ////////////////////////////////////////////////////////////////*/

        licenseRegistry.addPolicyToIp(ipAcct[1], policyIds["com_deriv_all_true"]);
        licenseRegistry.addPolicyToIp(ipAcct[3], policyIds["noncom_deriv_mint_payment"]);

        /*///////////////////////////////////////////////////////////////
                            MINT LICENSES ON POLICIES
        ////////////////////////////////////////////////////////////////*/

        // Carl mints 1 license for policy "com_deriv_all_true" on alice's NFT 1 IPAccount
        vm.startPrank(u.carl);
        uint256 carl_license_from_alice = licenseRegistry.mintLicense(
            policyIds["com_deriv_all_true"],
            ipAcct[1],
            1,
            u.carl
        );

        /*///////////////////////////////////////////////////////////////
                    LINK IPACCOUNTS TO PARENTS USING LICENSES
        ////////////////////////////////////////////////////////////////*/

        // Carl activates above license on his NFT 6 IPAccount, linking as child to Alice's NFT 1 IPAccount

        linkIpToParent(carl_license_from_alice, ipAcct[6], u.carl);
    }
}
