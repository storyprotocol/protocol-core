// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract
import { IRoyaltyPolicyLAP } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { PILFlavors } from "contracts/lib/PILFlavors.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.t.sol";

contract Licensing_Scenarios is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;
    uint256 nonCommRemixPoliciyId;

    bytes internal emptyRoyaltyPolicyLAPInitParams;

    function setUp() public override {
        super.setUp();

        // Register PIL Framework
        _deployLFM_PIL();

        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        mockNFT.mintId(u.bob, 2);

        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
        ipAcct[2] = registerIpAccount(mockNFT, 2, u.bob);

        nonCommRemixPoliciyId = _pilFramework().registerPolicy(PILFlavors.nonCommercialSocialRemixing());
        emptyRoyaltyPolicyLAPInitParams = abi.encode(
            IRoyaltyPolicyLAP.InitParams({
                targetAncestors: new address[](0),
                targetRoyaltyAmount: new uint32[](0),
                parentAncestors1: new address[](0),
                parentAncestors2: new address[](0),
                parentAncestorsRoyalties1: new uint32[](0),
                parentAncestorsRoyalties2: new uint32[](0)
            })
        );
    }

    function test_flavors_getId() public {
        uint256 id = PILFlavors.getNonCommercialSocialRemixingId(licensingModule, address(_pilFramework()));
        assertEq(id, nonCommRemixPoliciyId);
        uint32 commercialRevShare = 10;
        uint256 commRemixPolicyId = _pilFramework().registerPolicy(
            PILFlavors.commercialRemix(commercialRevShare, address(royaltyPolicyLAP))
        );
        assertEq(
            commRemixPolicyId,
            PILFlavors.getcommercialRemixId(
                licensingModule,
                address(_pilFramework()),
                commercialRevShare,
                address(royaltyPolicyLAP)
            )
        );

        uint256 mintFee = 100;
        uint256 commPolicyId = _pilFramework().registerPolicy(
            PILFlavors.commercialUse(mintFee, address(USDC), address(royaltyPolicyLAP))
        );
        assertEq(
            commPolicyId,
            PILFlavors.getCommercialUseId(
                licensingModule,
                address(_pilFramework()),
                mintFee,
                address(USDC),
                address(royaltyPolicyLAP)
            )
        );
    }

    function test_ipaHasNonCommercialAndCommercialPolicy_mintingLicenseFromCommercial() public {
        // Register commercial remixing policy
        uint32 commercialRevShare = 10;
        uint256 commRemixPolicyId = _pilFramework().registerPolicy(
            PILFlavors.commercialRemix(commercialRevShare, address(royaltyPolicyLAP))
        );

        // Register commercial use policy
        uint256 mintFee = 100;
        uint256 commPolicyId = _pilFramework().registerPolicy(
            PILFlavors.commercialUse(mintFee, address(USDC), address(royaltyPolicyLAP))
        );
        uint256[] memory licenseIds = new uint256[](1);

        // Add policies to IP account
        vm.startPrank(u.alice);
        licensingModule.addPolicyToIp(ipAcct[1], commRemixPolicyId);
        licensingModule.addPolicyToIp(ipAcct[1], nonCommRemixPoliciyId);
        licensingModule.addPolicyToIp(ipAcct[1], commPolicyId);
        vm.stopPrank();
        // Register new IPAs
        mockNFT.mintId(u.bob, 3);
        ipAcct[3] = registerIpAccount(mockNFT, 3, u.bob);
        mockNFT.mintId(u.bob, 4);
        ipAcct[4] = registerIpAccount(mockNFT, 4, u.bob);
        // Mint license for Non-commercial remixing, then link to new IPA to make it a derivative
        vm.startPrank(u.bob);
        licenseIds[0] = licensingModule.mintLicense(nonCommRemixPoliciyId, ipAcct[1], 1, u.bob, "");
        licensingModule.linkIpToParents(licenseIds, ipAcct[2], emptyRoyaltyPolicyLAPInitParams);
        // Mint license for commercial use, then link to new IPA to make it a derivative
        // Needs royalty context with 1 ancestor, since it's commercial
        IRoyaltyPolicyLAP.InitParams memory params = IRoyaltyPolicyLAP.InitParams({
            targetAncestors: new address[](1),
            targetRoyaltyAmount: new uint32[](1),
            parentAncestors1: new address[](0),
            parentAncestors2: new address[](0),
            parentAncestorsRoyalties1: new uint32[](0),
            parentAncestorsRoyalties2: new uint32[](0)
        });
        params.targetAncestors[0] = ipAcct[1];
        params.targetRoyaltyAmount[0] = 0;
        IERC20(USDC).approve(address(royaltyPolicyLAP), mintFee);
        licenseIds[0] = licensingModule.mintLicense(commPolicyId, ipAcct[1], 1, u.bob, emptyRoyaltyPolicyLAPInitParams);
        licensingModule.linkIpToParents(licenseIds, ipAcct[3], abi.encode(params));
        // Mint license for commercial remixing, then link to new IPA to make it a derivative
        // Needs royalty context with 1 ancestor, since it's commercial
        params = IRoyaltyPolicyLAP.InitParams({
            targetAncestors: new address[](1),
            targetRoyaltyAmount: new uint32[](1),
            parentAncestors1: new address[](0),
            parentAncestors2: new address[](0),
            parentAncestorsRoyalties1: new uint32[](0),
            parentAncestorsRoyalties2: new uint32[](0)
        });
        params.targetAncestors[0] = ipAcct[1];
        params.targetRoyaltyAmount[0] = commercialRevShare;
        licenseIds[0] = licensingModule.mintLicense(
            commRemixPolicyId,
            ipAcct[1],
            1,
            u.bob,
            emptyRoyaltyPolicyLAPInitParams
        );
        licensingModule.linkIpToParents(licenseIds, ipAcct[4], abi.encode(params));

        vm.stopPrank();
    }
}
