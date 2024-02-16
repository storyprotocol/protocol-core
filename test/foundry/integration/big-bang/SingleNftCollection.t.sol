// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// contract
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { IP } from "../../../../contracts/lib/IP.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";
import { UMLPolicy } from "../../../../contracts/modules/licensing/UMLPolicyFrameworkManager.sol";

// test
import { BaseIntegration } from "../BaseIntegration.t.sol";

contract BigBang_Integration_SingleNftCollection is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    mapping(string name => uint256 licenseId) internal licenseIds;

    function setUp() public override {
        super.setUp();

        // Add UML PFM policies

        _setUMLPolicyFrameworkManager();

        _addUMLPolicy(
            "com_deriv_cheap_flexible", // ==> policyIds["uml_com_deriv_cheap_flexible"]
            true,
            address(royaltyPolicyLAP),
            UMLPolicy({
                attribution: false,
                commercialUse: true,
                commercialAttribution: true,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 10,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: false,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            })
        );

        _addUMLPolicy(
            "noncom_deriv_reciprocal_derivative", // ==> policyIds["uml_noncom_deriv_reciprocal_derivative"]
            false,
            address(0),
            UMLPolicy({
                attribution: false,
                commercialUse: false,
                commercialAttribution: false,
                commercializerChecker: address(0),
                commercializerCheckerData: "",
                commercialRevShare: 0,
                derivativesAllowed: true,
                derivativesAttribution: true,
                derivativesApproval: false,
                derivativesReciprocal: true,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            })
        );
    }

    function test_Integration_SingleNftCollection_DirectCallsByIPAccountOwners() public {
        /*//////////////////////////////////////////////////////////////
                                REGISTER IP ACCOUNTS
        ///////////////////////////////////////////////////////////////*/

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

        /*//////////////////////////////////////////////////////////////
                            ADD POLICIES TO IP ACCOUNTS
        ///////////////////////////////////////////////////////////////*/

        vm.startPrank(u.alice);
        licensingModule.addPolicyToIp(ipAcct[1], policyIds["uml_com_deriv_cheap_flexible"]);
        licensingModule.addPolicyToIp(ipAcct[100], policyIds["uml_noncom_deriv_reciprocal_derivative"]);

        vm.startPrank(u.bob);
        licensingModule.addPolicyToIp(ipAcct[3], policyIds["uml_com_deriv_cheap_flexible"]);
        licensingModule.addPolicyToIp(ipAcct[300], policyIds["uml_com_deriv_cheap_flexible"]);

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
        ///////////////////////////////////////////////////////////////*/

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
                u.carl,
                ""
            );

            ipAcct[6] = registerIpAccount(mockNFT, 6, u.carl);
            // minRoyalty = 0 gets overridden by the `derivativesRevShare` value of the linking licenses
            linkIpToParents(carl_license_from_root_alice, ipAcct[6], u.carl, "");
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
                u.carl,
                ""
            );

            ipAcct[7] = registerIpAccount(mockNFT, 7, u.carl);
            // minRoyalty = 0 gets overridden by the `derivativesRevShare` value of the linking licenses
            linkIpToParents(carl_license_from_root_bob, ipAcct[7], u.carl, "");
        }

        // Alice mints 2 license for policy "uml_com_deriv_cheap_flexible" on Bob's NFT 3 IPAccount
        // Alice creates NFT 2 IPAccount
        // Alice activates one of the two licenses on her NFT 2 IPAccount, linking as child to Bob's NFT 3 IPAccount
        // Alice creates derivative NFT 3 directly using the other license
        {
            vm.startPrank(u.alice);
            mockNFT.mintId(u.alice, 2);
            uint256 mintAmount = 2;

            uint256[] memory alice_license_from_root_bob = new uint256[](1);
            alice_license_from_root_bob[0] = licensingModule.mintLicense(
                policyIds["uml_com_deriv_cheap_flexible"],
                ipAcct[3],
                mintAmount,
                u.alice,
                ""
            );

            ipAcct[2] = registerIpAccount(mockNFT, 2, u.alice);
            linkIpToParents(alice_license_from_root_bob, ipAcct[2], u.alice, "");

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
                ""
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

            IP.MetadataV1 memory metadata = IP.MetadataV1({
                name: "IP NAME",
                hash: bytes32("hash"),
                registrationDate: uint64(block.timestamp),
                registrant: u.carl, // caller
                uri: "external URL"
            });

            uint256[] memory carl_licenses = new uint256[](2);
            // Commercial license
            carl_licenses[0] = licensingModule.mintLicense(
                policyIds["uml_com_deriv_cheap_flexible"], // ipAcct[1] has this policy attached
                ipAcct[1],
                100, // mint 100 licenses
                u.carl,
                ""
            );

            // Non-commercial license
            carl_licenses[1] = licensingModule.mintLicense(
                policyIds["uml_noncom_deriv_reciprocal_derivative"], // ipAcct[3] has this policy attached
                ipAcct[3],
                1,
                u.carl,
                ""
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
                ""
            );

            // Modify license[1] to a Commercial license
            carl_licenses[1] = licensingModule.mintLicense(
                policyIds["uml_com_deriv_cheap_flexible"], // ipAcct[300] has this policy attached
                ipAcct[300],
                1,
                u.carl,
                ""
            );

            // This should succeed since both license[0] and license[1] are commercial
            registerDerivativeIps(
                carl_licenses, // ipAcct[1] and ipAcct[3] licenses
                address(mockNFT),
                tokenId,
                metadata,
                u.carl, // caller
                ""
            );
        }
    }
}
