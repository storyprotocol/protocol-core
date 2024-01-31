// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { console2 } from "forge-std/console2.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contracts
import { ILiquidSplitFactory } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitFactory.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { UMLPolicyFrameworkManager } from "contracts/modules/licensing/UMLPolicyFrameworkManager.sol";
import { ILiquidSplitClone } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { ILiquidSplitMain } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { LSClaimer } from "contracts/modules/royalty-module/policies/LSClaimer.sol";
import { RoyaltyPolicyLS } from "contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";

// test
import { UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/integration/shared/LicenseFrameworkPolicy.sol";
import { MintPaymentPolicyFrameworkManager } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { TestHelper } from "test/utils/TestHelper.sol";

contract TestLSClaimer is TestHelper {
    address[] public LONG_CHAIN = new address[](100);
    address[] public accounts = new address[](2);
    uint32[] public initAllocations = new uint32[](2);
    address public splitClone100;
    LSClaimer public lsClaimer100;
    uint32 public royaltyStack100;
    uint32 public minRoyalty100;
    ERC20[] public tokens = new ERC20[](1);
    uint256 public ethRoyaltyAmount = 1 ether;
    uint256 public usdcRoyaltyAmount = 1000 * 10 ** 6;

    function setUp() public override {
        TestHelper.setUp();
        _setUMLPolicyFrameworkManager();
        nft = new MockERC721("mock");
        _addUMLPolicy(
            true,
            true,
            UMLPolicyGenericParams({
                policyName: "cheap_flexible", // => uml_cheap_flexible
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
        );

        _setLsClaimer();
    }

    function _setLsClaimer() internal {
        vm.startPrank(deployer);
        for (uint256 i = 1; i < 101; i++) {
            nft.mintId(deployer, i);
            nftIds.push(i);
        }
    
        registrationModule.registerRootIp(policyIds["uml_cheap_flexible"],address(nft), nftIds[1]);
        vm.stopPrank();

        for (uint256 i = 1; i < 100; i++) {
            uint256 licenseId = licenseRegistry.mintLicense(
                policyIds["uml_cheap_flexible"],
                _getIpId(nft, nftIds[i]),
                2,
                deployer
            );

            vm.startPrank(_getIpId(nft, nftIds[i]));
            registrationModule.registerDerivativeIp(licenseId, address(nft), nftIds[i + 1], "", bytes32(""), "");
            vm.stopPrank();
        }
        
        // /*///////////////////////////////////////////////////////////////
        //                     SET UP LSCLAIMER
        // ////////////////////////////////////////////////////////////////*/

        RoyaltyPolicyLS testRoyaltyPolicyLS;
        testRoyaltyPolicyLS = new RoyaltyPolicyLS(
            address(1),
            address(licenseRegistry),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN
        );

        vm.startPrank(address(1));
        // set up root royalty policy
        address[] memory parentsIds1 = new address[](1);
        testRoyaltyPolicyLS.initPolicy(_getIpId(nft, nftIds[1]), parentsIds1, abi.encode(10));

        // set up derivative royalty policy
        for (uint256 i = 1; i < 100; i++) {
            address[] memory parentsIds = new address[](1);
            parentsIds[0] = _getIpId(nft, nftIds[i]);
            testRoyaltyPolicyLS.initPolicy(_getIpId(nft, nftIds[i + 1]), parentsIds, abi.encode(10));
        }
        vm.stopPrank();

        (address split, address claimer, uint32 rStack, uint32 mRoyalty) = testRoyaltyPolicyLS.royaltyData(
            _getIpId(nft, nftIds[100])
        );
        lsClaimer100 = LSClaimer(claimer);
        splitClone100 = split;
        royaltyStack100 = rStack;
        minRoyalty100 = mRoyalty;

        // set up longest chain possible of 100 elements
        for (uint256 i = 0; i < 100; i++) {
            LONG_CHAIN[i] = _getIpId(nft, nftIds[i + 1]);
        }
        assertEq(LONG_CHAIN[0], _getIpId(nft, nftIds[1]));
        assertEq(LONG_CHAIN[99], _getIpId(nft, nftIds[100]));
        assertEq(LONG_CHAIN.length, 100);
        assertEq(royaltyStack100, 1000);
    }

    function test_LSClaimer_constructor_revert_ZeroIpId() public {
        vm.expectRevert(Errors.LSClaimer__ZeroIpId.selector);
        new LSClaimer(address(0), address(licenseRegistry), address(royaltyPolicyLS));
    }

    function test_LSClaimer_constructor_revert_ZeroLicenseRegistry() public {
        vm.expectRevert(Errors.LSClaimer__ZeroLicenseRegistry.selector);
        new LSClaimer(address(1), address(0), address(royaltyPolicyLS));
    }

    function test_LSClaimer_constructor_revert_ZeroRoyaltyPolicyLS() public {
        vm.expectRevert(Errors.LSClaimer__ZeroRoyaltyPolicyLS.selector);
        new LSClaimer(address(1), address(licenseRegistry), address(0));
    }

    function test_LSClaimer_constructor() public {
        LSClaimer testLsClaimer = new LSClaimer(address(1), address(licenseRegistry), address(royaltyPolicyLS));

        assertEq(address(testLsClaimer.IP_ID()), address(1));
        assertEq(address(testLsClaimer.ILICENSE_REGISTRY()), address(licenseRegistry));
        assertEq(address(testLsClaimer.IROYALTY_POLICY_LS()), address(royaltyPolicyLS));
    }

    function test_LSClaimer_claim_revert_AlreadyClaimed() public {
        address claimerIpId = _getIpId(nft, nftIds[1]);
        tokens[0] = ERC20(USDC);

        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);

        vm.expectRevert(Errors.LSClaimer__AlreadyClaimed.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    function test_LSClaimer_claim_revert_InvalidPathFirstPosition() public {
        tokens[0] = ERC20(USDC);

        vm.expectRevert(Errors.LSClaimer__InvalidPathFirstPosition.selector);
        lsClaimer100.claim(LONG_CHAIN, address(0), true, tokens);
    }

    function test_LSClaimer_claim_revert_InvalidPathLastPosition() public {
        address claimerIpId = _getIpId(nft, nftIds[1]);
        tokens[0] = ERC20(USDC);

        LONG_CHAIN.push(address(1));

        vm.expectRevert(Errors.LSClaimer__InvalidPathLastPosition.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    function test_LSClaimer_claim_revert_InvalidPath() public {
        address claimerIpId = _getIpId(nft, nftIds[1]);
        tokens[0] = ERC20(USDC);

        LONG_CHAIN[5] = address(1);

        vm.expectRevert(Errors.LSClaimer__InvalidPath.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    function test_LSClaimer_claim_revert_ERC20BalanceNotZero() public {
        vm.startPrank(USDC_RICH);
        IERC20(USDC).transfer(address(splitClone100), usdcRoyaltyAmount);
        vm.stopPrank();

        accounts[0] = _getIpId(nft, nftIds[100]);
        accounts[1] = address(lsClaimer100);

        ILiquidSplitClone(splitClone100).distributeFunds(USDC, accounts, address(0));

        ERC20 token_ = ERC20(USDC);
        assertGt(
            ILiquidSplitMain(royaltyPolicyLS.LIQUID_SPLIT_MAIN()).getERC20Balance(address(lsClaimer100), token_),
            0
        );

        address claimerIpId = _getIpId(nft, nftIds[1]);
        tokens[0] = ERC20(USDC);

        vm.expectRevert(Errors.LSClaimer__ERC20BalanceNotZero.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    function test_LSClaimer_claim_revert_ETHBalanceNotZero() public {
        vm.deal(address(splitClone100), ethRoyaltyAmount);

        accounts[0] = _getIpId(nft, nftIds[100]);
        accounts[1] = address(lsClaimer100);

        ILiquidSplitClone(splitClone100).distributeFunds(address(0), accounts, address(0));

        assertGt(ILiquidSplitMain(royaltyPolicyLS.LIQUID_SPLIT_MAIN()).getETHBalance(address(lsClaimer100)), 0);

        address claimerIpId = _getIpId(nft, nftIds[1]);
        tokens[0] = ERC20(USDC);

        vm.expectRevert(Errors.LSClaimer__ETHBalanceNotZero.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    function test_LSClaimer_claim() public {
        // claimer contract receives royalties
        vm.deal(address(lsClaimer100), ethRoyaltyAmount);
        vm.startPrank(USDC_RICH);
        IERC20(USDC).transfer(address(lsClaimer100), usdcRoyaltyAmount);
        vm.stopPrank();

        address claimerIpId = _getIpId(nft, nftIds[1]);
        tokens[0] = ERC20(USDC);

        uint256 lsClaimerUSDCBalBefore = IERC20(USDC).balanceOf(address(lsClaimer100));
        uint256 lsClaimerETHBalBefore = address(lsClaimer100).balance;
        uint256 lsClaimerRNFTBalBefore = ILiquidSplitClone(splitClone100).balanceOf(address(lsClaimer100), 0);
        uint256 claimerUSDCBalBefore = IERC20(USDC).balanceOf(claimerIpId);
        uint256 claimerETHBalBefore = address(claimerIpId).balance;
        uint256 claimerRNFTBalBefore = ILiquidSplitClone(splitClone100).balanceOf(claimerIpId, 0);

        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);

        uint256 lsClaimerUSDCBalAfter = IERC20(USDC).balanceOf(address(lsClaimer100));
        uint256 lsClaimerETHBalAfter = address(lsClaimer100).balance;
        uint256 lsClaimerRNFTBalAfter = ILiquidSplitClone(splitClone100).balanceOf(address(lsClaimer100), 0);
        uint256 claimerUSDCBalAfter = IERC20(USDC).balanceOf(claimerIpId);
        uint256 claimerETHBalAfter = address(claimerIpId).balance;
        uint256 claimerRNFTBalAfter = ILiquidSplitClone(splitClone100).balanceOf(claimerIpId, 0);

        assertEq(lsClaimer100.claimedPaths(keccak256(abi.encodePacked(LONG_CHAIN))), true);
        assertEq(
            lsClaimerUSDCBalBefore - lsClaimerUSDCBalAfter,
            (usdcRoyaltyAmount * minRoyalty100) / (royaltyStack100 - minRoyalty100)
        ); // calculation not aggregated in a variable due to stack too deep error
        assertEq(
            lsClaimerETHBalBefore - lsClaimerETHBalAfter,
            (ethRoyaltyAmount * minRoyalty100) / (royaltyStack100 - minRoyalty100)
        );
        assertEq(lsClaimerRNFTBalBefore - lsClaimerRNFTBalAfter, minRoyalty100);
        assertEq(
            claimerUSDCBalAfter - claimerUSDCBalBefore,
            (usdcRoyaltyAmount * minRoyalty100) / (royaltyStack100 - minRoyalty100)
        );
        assertEq(
            claimerETHBalAfter - claimerETHBalBefore,
            (ethRoyaltyAmount * minRoyalty100) / (royaltyStack100 - minRoyalty100)
        );
        assertEq(claimerRNFTBalAfter - claimerRNFTBalBefore, minRoyalty100);
    }
}
