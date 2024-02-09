// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC6551AccountLib } from "@erc6551/lib/ERC6551AccountLib.sol";

// contracts
import { Errors } from "contracts/lib/Errors.sol";
import { ILiquidSplitClone } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { ILiquidSplitMain } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { LSClaimer } from "contracts/modules/royalty-module/policies/LSClaimer.sol";
import { RoyaltyPolicyLS } from "contracts/modules/royalty-module/policies/RoyaltyPolicyLS.sol";

// test
// solhint-disable-next-line max-line-length
import { UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/integration/shared/LicenseHelper.sol";
import { TestHelper } from "test/foundry/utils/TestHelper.sol";

contract TestLSClaimer is TestHelper {
    RoyaltyPolicyLS public testRoyaltyPolicyLS;
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
        nft = erc721.ape;
        _addUMLPolicy(
            true,
            true,
            UMLPolicyGenericParams({
                policyName: "cheap_flexible", // => uml_cheap_flexible
                attribution: false,
                transferable: true,
                territories: new string[](0),
                distributionChannels: new string[](0),
                contentRestrictions: new string[](0)
            }),
            UMLPolicyCommercialParams({
                commercialAttribution: true,
                commercializers: new string[](0),
                commercialRevShare: 10,
                royaltyPolicy: address(royaltyPolicyLS),
                mintingFeeAmount: 0, // no upfront payment for LSClaimer
                mintingFeeToken: address(USDC)
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
        for (uint256 i = 0; i < 101; i++) {
            nft.mintId(deployer, i);
            nftIds.push(i);
        }

        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            address(nft),
            nftIds[0]
        );
        vm.label(expectedAddr, string(abi.encodePacked("IPAccount", Strings.toString(nftIds[0]))));

        ipAssetRegistry.setApprovalForAll(address(registrationModule), true);
        address ipAddr = registrationModule.registerRootIp(
            policyIds["uml_cheap_flexible"],
            address(nft),
            nftIds[0],
            "IPAccount1",
            bytes32("some of the best description"),
            "https://example.com/test-ip"
        );
        vm.label(ipAddr, string(abi.encodePacked("IPAccount", Strings.toString(nftIds[0]))));
        vm.stopPrank();
        vm.startPrank(address(licensingModule));
        royaltyModule.setRoyaltyPolicy(
            ipAddr,
            address(royaltyPolicyLS),
            new address[](0), // no parent
            abi.encode(10)
        );

        vm.stopPrank();
        vm.startPrank(deployer);
        USDC.approve(address(royaltyPolicyLS), type(uint256).max);
        uint256[] memory licenseId = new uint256[](1);
        for (uint256 i = 0; i < 99; i++) {
            licenseId[0] = licensingModule.mintLicense(
                policyIds["uml_cheap_flexible"],
                _getIpId(nft, nftIds[i]),
                2,
                deployer
            );

            expectedAddr = ERC6551AccountLib.computeAddress(
                address(erc6551Registry),
                address(ipAccountImpl),
                ipAccountRegistry.IP_ACCOUNT_SALT(),
                block.chainid,
                address(nft),
                nftIds[i + 1]
            );
            string memory ipAcctName = string(abi.encodePacked("IPAccount", Strings.toString(nftIds[i + 1])));
            vm.label(expectedAddr, ipAcctName);

            registrationModule.registerDerivativeIp(
                licenseId,
                address(nft),
                nftIds[i + 1],
                ipAcctName,
                bytes32("ipAccount hash"),
                "ipAccount External URL",
                0 // gets overridden by the `derivativesRevShare` value of the linking licenses
            );
        }

        // /*///////////////////////////////////////////////////////////////
        //                     SET UP LSCLAIMER
        // ////////////////////////////////////////////////////////////////*/

        testRoyaltyPolicyLS = new RoyaltyPolicyLS(
            address(1),
            address(licensingModule),
            LIQUID_SPLIT_FACTORY,
            LIQUID_SPLIT_MAIN
        );

        vm.startPrank(address(1));
        // set up root royalty policy
        address[] memory parentsIds1 = new address[](1);
        testRoyaltyPolicyLS.initPolicy(_getIpId(nft, nftIds[0]), parentsIds1, abi.encode(10));

        // set up derivative royalty policy
        for (uint256 i = 0; i < 99; i++) {
            address[] memory parentsIds = new address[](1);
            parentsIds[0] = _getIpId(nft, nftIds[i]);
            testRoyaltyPolicyLS.initPolicy(_getIpId(nft, nftIds[i + 1]), parentsIds, abi.encode(10));
        }
        vm.stopPrank();

        (address split, address claimer, uint32 rStack, uint32 mRoyalty) = testRoyaltyPolicyLS.royaltyData(
            _getIpId(nft, nftIds[99])
        );
        lsClaimer100 = LSClaimer(claimer);
        splitClone100 = split;
        royaltyStack100 = rStack;
        minRoyalty100 = mRoyalty;

        // set up longest chain possible of 100 elements
        for (uint256 i = 0; i < 100; i++) {
            LONG_CHAIN[i] = _getIpId(nft, nftIds[i]);
        }
        assertEq(LONG_CHAIN[0], _getIpId(nft, nftIds[0]));
        assertEq(LONG_CHAIN[99], _getIpId(nft, nftIds[99]));
        assertEq(LONG_CHAIN.length, 100);
        assertEq(royaltyStack100, 1000);
    }

    function test_LSClaimer_constructor_revert_ZeroIpId() public {
        vm.expectRevert(Errors.LSClaimer__ZeroIpId.selector);
        new LSClaimer(address(0), address(licensingModule), address(royaltyPolicyLS));
    }

    function test_LSClaimer_constructor_revert_ZeroLicensingModule() public {
        vm.expectRevert(Errors.LSClaimer__ZeroLicensingModule.selector);
        new LSClaimer(address(1), address(0), address(royaltyPolicyLS));
    }

    function test_LSClaimer_constructor_revert_ZeroRoyaltyPolicyLS() public {
        vm.expectRevert(Errors.LSClaimer__ZeroRoyaltyPolicyLS.selector);
        new LSClaimer(address(1), address(licensingModule), address(0));
    }

    function test_LSClaimer_constructor() public {
        LSClaimer testLsClaimer = new LSClaimer(address(1), address(licensingModule), address(royaltyPolicyLS));

        assertEq(address(testLsClaimer.IP_ID()), address(1));
        assertEq(address(testLsClaimer.LICENSING_MODULE()), address(licensingModule));
        assertEq(address(testLsClaimer.IROYALTY_POLICY_LS()), address(royaltyPolicyLS));
    }

    function test_LSClaimer_claim_revert_AlreadyClaimed() public {
        address claimerIpId = _getIpId(nft, nftIds[0]);
        tokens[0] = USDC;

        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);

        vm.expectRevert(Errors.LSClaimer__AlreadyClaimed.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    function test_LSClaimer_claim_revert_InvalidPathFirstPosition() public {
        tokens[0] = USDC;

        vm.expectRevert(Errors.LSClaimer__InvalidPathFirstPosition.selector);
        lsClaimer100.claim(LONG_CHAIN, address(0), true, tokens);
    }

    function test_LSClaimer_claim_revert_InvalidPathLastPosition() public {
        address claimerIpId = _getIpId(nft, nftIds[0]);
        tokens[0] = USDC;

        LONG_CHAIN.push(address(1));

        vm.expectRevert(Errors.LSClaimer__InvalidPathLastPosition.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    function test_LSClaimer_claim_revert_InvalidPath() public {
        address claimerIpId = _getIpId(nft, nftIds[0]);
        tokens[0] = USDC;

        LONG_CHAIN[5] = address(1);

        vm.expectRevert(Errors.LSClaimer__InvalidPath.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    // TODO: fix this not-failing (expected to fail) test case
    // function test_LSClaimer_claim_revert_ERC20BalanceNotZero() public {
    //     USDC.mint(ipAccount1, usdcRoyaltyAmount);

    //     accounts[0] = _getIpId(nft, nftIds[99]);
    //     accounts[1] = address(lsClaimer100);

    //     ILiquidSplitClone(splitClone100).distributeFunds(address(USDC), accounts, address(0));

    //     ERC20 token_ = USDC;
    //     assertGt(
    //         ILiquidSplitMain(royaltyPolicyLS.LIQUID_SPLIT_MAIN()).getERC20Balance(address(lsClaimer100), token_),
    //         1 // value of 0 is stored as 1 in 0xSplits (for cheaper, warm storage)
    //     );

    //     address claimerIpId = _getIpId(nft, nftIds[0]);
    //     tokens[0] = USDC;

    //     vm.expectRevert(Errors.LSClaimer__ERC20BalanceNotZero.selector);
    //     lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    // }

    function test_LSClaimer_claim_revert_ETHBalanceNotZero() public {
        vm.deal(address(splitClone100), ethRoyaltyAmount);

        accounts[0] = _getIpId(nft, nftIds[99]);
        accounts[1] = address(lsClaimer100);

        ILiquidSplitClone(splitClone100).distributeFunds(address(0), accounts, address(0));

        assertGt(ILiquidSplitMain(royaltyPolicyLS.LIQUID_SPLIT_MAIN()).getETHBalance(address(lsClaimer100)), 0);

        address claimerIpId = _getIpId(nft, nftIds[0]);
        tokens[0] = USDC;

        vm.expectRevert(Errors.LSClaimer__ETHBalanceNotZero.selector);
        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);
    }

    function test_LSClaimer_claim() public {
        // claimer contract receives royalties
        vm.deal(address(lsClaimer100), ethRoyaltyAmount);
        USDC.mint(address(lsClaimer100), usdcRoyaltyAmount);

        address claimerIpId = _getIpId(nft, nftIds[0]);
        (address claimerSplitClone, , , ) = testRoyaltyPolicyLS.royaltyData(_getIpId(nft, nftIds[0]));
        tokens[0] = USDC;

        uint256 lsClaimerUSDCBalBefore = USDC.balanceOf(address(lsClaimer100));
        uint256 lsClaimerETHBalBefore = address(lsClaimer100).balance;
        uint256 lsClaimerRNFTBalBefore = ILiquidSplitClone(splitClone100).balanceOf(address(lsClaimer100), 0);
        uint256 claimerSplitUSDCBalBefore = USDC.balanceOf(claimerSplitClone);
        uint256 claimerSplitETHBalBefore = address(claimerSplitClone).balance;
        uint256 claimerSplitRNFTBalBefore = ILiquidSplitClone(splitClone100).balanceOf(claimerSplitClone, 0);

        lsClaimer100.claim(LONG_CHAIN, claimerIpId, true, tokens);

        uint256 lsClaimerUSDCBalAfter = USDC.balanceOf(address(lsClaimer100));
        uint256 lsClaimerETHBalAfter = address(lsClaimer100).balance;
        uint256 lsClaimerRNFTBalAfter = ILiquidSplitClone(splitClone100).balanceOf(address(lsClaimer100), 0);
        uint256 claimerSplitUSDCBalAfter = USDC.balanceOf(claimerSplitClone);
        uint256 claimerSplitETHBalAfter = address(claimerSplitClone).balance;
        uint256 claimerSplitRNFTBalAfter = ILiquidSplitClone(splitClone100).balanceOf(claimerSplitClone, 0);

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
            claimerSplitUSDCBalAfter - claimerSplitUSDCBalBefore,
            (usdcRoyaltyAmount * minRoyalty100) / (royaltyStack100 - minRoyalty100)
        );
        assertEq(
            claimerSplitETHBalAfter - claimerSplitETHBalBefore,
            (ethRoyaltyAmount * minRoyalty100) / (royaltyStack100 - minRoyalty100)
        );
        assertEq(claimerSplitRNFTBalAfter - claimerSplitRNFTBalBefore, minRoyalty100);
    }
}
