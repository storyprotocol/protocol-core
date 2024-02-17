// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract
import { IRoyaltyPolicyLAP } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.t.sol";

contract Flows_Integration_Disputes is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;

    bytes internal emptyRoyaltyPolicyLAPInitParams =
        abi.encode(
            IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](0),
                targetRoyaltyAmount: new uint32[](0),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            })
        );

    uint32 internal defaultCommRevShare = 100;

    function setUp() public override {
        super.setUp();

        // Register PIL Framework
        _deployLFM_PIL();

        // Register a License
        _mapPILPolicySimple({
            name: "commercial-remix",
            commercial: true,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: defaultCommRevShare
        });
        _registerPILPolicyFromMapping("commercial-remix");

        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);
        mockNFT.mintId(u.carl, 3);
    }

    function test_Integration_Royalty() public {
        {
            vm.startPrank(u.alice);

            ipAcct[1] = _getIpId(mockNFT, 1);
            vm.label(ipAcct[1], "IPAccount1");

            registerIpAccount(mockNFT, 1, u.alice);
            licensingModule.addPolicyToIp(ipAcct[1], _getPilPolicyId("commercial-remix"));
            vm.stopPrank();
        }

        // Bob mints 1 license of policy "pil-commercial-remix" from IPAccount1 and registers the derivative IP for
        // NFT tokenId 2.
        {
            vm.startPrank(u.bob);

            ipAcct[2] = _getIpId(mockNFT, 2);
            vm.label(ipAcct[2], "IPAccount2");

            uint256[] memory licenseIds = new uint256[](1);
            licenseIds[0] = licensingModule.mintLicense(
                _getPilPolicyId("commercial-remix"),
                ipAcct[1],
                1,
                u.bob,
                emptyRoyaltyPolicyLAPInitParams
            );

            IRoyaltyPolicyLAP.InitParams memory params = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            params.targetAncestors[0] = ipAcct[1];
            params.targetRoyaltyAmount[0] = defaultCommRevShare;

            registrationModule.registerDerivativeIp(
                licenseIds,
                address(mockNFT),
                2,
                "IPAccount2",
                bytes32("some of the best description"),
                "https://example.com/best-derivative-ip",
                abi.encode(params)
            );

            vm.stopPrank();
        }

        // Carl mints 1 license of policy "pil-commercial-remix" from IPAccount1 and IPAccount2 and registers the
        // derivative IP for NFT tokenId 3. Thus, IPAccount3 is a derivative of both IPAccount1 and IPAccount2.
        // More precisely, IPAccount1 is a grandparent and IPAccount2 is a parent of IPAccount3.
        {
            vm.startPrank(u.carl);

            ipAcct[3] = _getIpId(mockNFT, 3);
            vm.label(ipAcct[3], "IPAccount3");

            uint256[] memory licenseIds = new uint256[](2);

            licenseIds[0] = licensingModule.mintLicense(
                _getPilPolicyId("commercial-remix"),
                ipAcct[1], // grandparent, root IP
                1,
                u.carl,
                emptyRoyaltyPolicyLAPInitParams
            );

            IRoyaltyPolicyLAP.InitParams memory params1 = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](1),
                targetRoyaltyAmount: new uint32[](1),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            });
            params1.targetAncestors[0] = ipAcct[1];
            params1.targetRoyaltyAmount[0] = defaultCommRevShare;

            licenseIds[1] = licensingModule.mintLicense(
                _getPilPolicyId("commercial-remix"),
                ipAcct[2], // parent, is child IP of ipAcct[1]
                1,
                u.carl,
                abi.encode(params1)
            );

            IRoyaltyPolicyLAP.InitParams memory params2 = IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](2),
                targetRoyaltyAmount: new uint32[](2),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](1),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](1)
            });
            params2.targetAncestors[0] = ipAcct[1]; // grandparent
            params2.targetAncestors[1] = ipAcct[2]; // parent
            params2.targetRoyaltyAmount[0] = defaultCommRevShare * 2; // owed to grandparent (twice - royalty stack!)
            params2.targetRoyaltyAmount[1] = defaultCommRevShare; // owed to parent
            params2.parentAncestors2[0] = ipAcct[1];
            params2.parentAncestorsRoyalties2[0] = defaultCommRevShare;

            registrationModule.registerDerivativeIp(
                licenseIds,
                address(mockNFT),
                3,
                "IPAccount3",
                bytes32("some of the best description"),
                "https://example.com/best-derivative-ip",
                abi.encode(params2)
            );

            vm.stopPrank();
        }

        // IPAccount1 and IPAccount2 have commercial policy, of which IPAccount3 has used to mint licenses and link.
        // Thus, any payment to IPAccount3 will get split to IPAccount1 and IPAccount2 accordingly to policy.

        // A new user, who likes IPAccount3, decides to pay IPAccount3 some royalty (1 token).
        {
            address newUser = address(0xbeef);
            vm.startPrank(newUser);

            mockToken.mint(newUser, 1 ether);

            mockToken.approve(address(royaltyPolicyLAP), 1 ether);
            // ipAcct[3] is the receiver, the actual token is paid by the caller (newUser).
            royaltyModule.payRoyaltyOnBehalf(ipAcct[3], ipAcct[3], address(mockToken), 1 ether);

            vm.stopPrank();
        }

        // Distribute the accrued revenue from the 0xSplitWallet associated with IPAccount3 to 0xSplits Main,
        // which will get distributed to IPAccount3 AND its claimer based on revenue sharing terms specified in the
        // royalty policy. Anyone can call this function. (Below, Dan calls as an example.)
        {
            vm.startPrank(u.dan);

            (, , address ipAcct3_ancestorVault, , ) = royaltyPolicyLAP.royaltyData(ipAcct[3]);

            address[] memory accounts = new address[](2);
            // If you face InvalidSplit__AccountsOutOfOrder, shuffle the order of accounts (swap index 0 and 1)
            accounts[1] = ipAcct[3];
            accounts[0] = ipAcct3_ancestorVault;

            royaltyPolicyLAP.distributeIpPoolFunds(ipAcct[3], address(mockToken), accounts, address(u.dan));

            vm.stopPrank();
        }

        // IPAccount2 claims its rNFTs and tokens, only done once since it's a direct chain
        {
            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = mockToken;

            // First, release the money from the IPAccount3's 0xSplitWallet (that just received money) to the main
            // 0xSplitMain that acts as a ledger for revenue distribution.
            // vm.expectEmit(LIQUID_SPLIT_MAIN);
            // TODO: check Withdrawal(699999999999999998) (Royalty stack is 300, or 30% [absolute] sent to ancestors)
            royaltyPolicyLAP.claimFromIpPool({ account: ipAcct[3], withdrawETH: 0, tokens: tokens });

            // Bob (owner of IPAccount2) calls the claim her portion of rNFTs and tokens. He can only call
            // `claimFromAncestorsVault` once. Afterwards, she will automatically receive money on revenue distribution.

            address[] memory ancestors = new address[](2);
            uint32[] memory ancestorsRoyalties = new uint32[](2);
            ancestors[0] = ipAcct[1]; // grandparent
            ancestors[1] = ipAcct[2]; // parent (claimer)
            ancestorsRoyalties[0] = defaultCommRevShare * 2;
            ancestorsRoyalties[1] = defaultCommRevShare;

            // IPAccount2 wants to claim from IPAccount3
            // TODO: AncestorsVaultLAP__ERC20BalanceNotZero (value is at 299999999999999999, which is ~30% of 1 ether)
            // royaltyPolicyLAP.claimFromAncestorsVault({
            //     ipId: ipAcct[3],
            //     claimerIpId: ipAcct[2],
            //     ancestors: ancestors,
            //     ancestorsRoyalties: ancestorsRoyalties,
            //     withdrawETH: false,
            //     tokens: tokens
            // });
        }
    }
}
