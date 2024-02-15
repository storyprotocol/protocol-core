// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IP } from "contracts/lib/IP.sol";
import { Errors } from "contracts/lib/Errors.sol";

// test
import { BaseIntegration } from "test/foundry/integration/BaseIntegration.t.sol";
import { MintPaymentPolicyFrameworkManager } from "test/foundry/mocks/licensing/MintPaymentPolicyFrameworkManager.sol";
import { UMLPolicyGenericParams, UMLPolicyCommercialParams, UMLPolicyDerivativeParams } from "test/foundry/utils/LicensingHelper.t.sol";

contract DisputeIntegrationTest is BaseIntegration {
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for *;

    mapping(uint256 tokenId => address ipAccount) internal ipAcct;
    uint256 policyId;

    function setUp() public override {
        super.setUp();
        
        // Register UML Framework
        _deployLFM_UML();
        
        // Register a License
        _mapUMLPolicySimple({
            name: "non-commercial-remix",
            commercial: false,
            derivatives: true,
            reciprocal: true,
            commercialRevShare: 0,
            derivativesRevShare: 0
        });
        policyId = _registerUMLPolicyFromMapping("non-commercial-remix");
        /*
        // Register an original work with both policies set
        mockNFT.mintId(u.alice, 1);
        vm.startPrank(u.alice);
        ipAcct[1] = registerIpAccount(mockNFT, 1, u.alice);
        licensingModule.addPolicyToIp(ipAcct[1], _getUmlPolicyId("non-commercial-remix"));
        */
    }

    function test_Disputes_revert_cannotMintFromDisputedIp() public {
        _disputeIp(ipAcct[1]);
        vm.startPrank(u.alice);
        vm.expectRevert(Errors.LicensingModule__DisputedIpId.selector);
        licensingModule.mintLicense(policyId, ipAcct[1], 1, u.bob);
    }

    function test_Disputes_revert_cannotLinkDisputedIp() public {

    }

    function _disputeIp(address ipAddr) public {
        vm.startPrank(u.bob);
        IERC20(USDC).approve(address(arbitrationPolicySP), ARBITRATION_PRICE);
        uint256 disputeId = disputeModule.raiseDispute(ipAddr, string("urlExample"), "PLAGIARISM", "");
        vm.stopPrank();

        vm.prank(u.admin);
        disputeModule.setDisputeJudgement(disputeId, true, "");
    }

}