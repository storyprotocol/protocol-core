/* // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IAncestorsVaultLAP } from "../../../interfaces/modules/royalty/policies/IAncestorsVaultLAP.sol";
import { ILiquidSplitClone } from "../../../interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { ILiquidSplitMain } from "../../../interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { IRoyaltyPolicyLAP } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { RoyaltyPolicyLAP } from "../../../../contracts/modules/royalty-module/policies/RoyaltyPolicyLAP.sol";
import { ArrayUtils } from "../../../lib/ArrayUtils.sol";
import { Errors } from "../../../lib/Errors.sol";

import "forge-std/console.sol"; 

contract AncestorsVaultLAP is IAncestorsVaultLAP, ERC1155Holder, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IRoyaltyPolicyLAP public immutable IROYALTY_POLICY_LAP;

    mapping(address ipId => mapping(address claimerIpId => bool)) public isClaimed;

    /// @notice Constructor
    /// @param _royaltyPolicyLAP The liquid split royalty policy address
    constructor(address _royaltyPolicyLAP) {
        if (_royaltyPolicyLAP == address(0)) revert Errors.AncestorsVaultLAP__ZeroRoyaltyPolicyLAP();

        IROYALTY_POLICY_LAP = IRoyaltyPolicyLAP(_royaltyPolicyLAP);
    }

    //TODO: double check everything given this is a permissionless call
    function claim(        
        address _ipId,
        address _claimerIpId,
        address[] calldata _ancestors,
        uint32[] calldata _ancestorsRoyalties,
        bool _withdrawETH,
        ERC20[] calldata _tokens
    ) external nonReentrant {
        (address splitClone, address ancestorsVault,, bytes32 ancestorsHash) = IROYALTY_POLICY_LAP.royaltyData(_ipId);

        if (isClaimed[_ipId][_claimerIpId]) revert Errors.AncestorsVaultLAP__AlreadyClaimed();
        if (address(this) != ancestorsVault) revert Errors.AncestorsVaultLAP__InvalidClaimer();
        if(keccak256(abi.encodePacked(_ancestors, _ancestorsRoyalties)) != ancestorsHash) revert Errors.AncestorsVaultLAP__InvalidAncestorsHash();

        // transfer the rnfts to the claimer accrued royalties to the claimer split clone
        _transferRnftsAndAccruedTokens(_claimerIpId, splitClone, _ancestors, _ancestorsRoyalties, _withdrawETH, _tokens);

        isClaimed[_ipId][_claimerIpId] = true;

        emit Claimed(_ipId, _claimerIpId, _withdrawETH, _tokens);
    }

    function _transferRnftsAndAccruedTokens(address _claimerIpId, address _splitClone, address[] calldata _ancestors, uint32[] calldata _ancestorsRoyalties, bool _withdrawETH, ERC20[] calldata _tokens) internal {
        (uint32 index, bool isIn) = ArrayUtils.indexOf(_ancestors, _claimerIpId);
        if (!isIn) revert Errors.AncestorsVaultLAP__ClaimerNotAnAncestor();
        
        // transfer the rnfts to the claimer split clone
        ILiquidSplitClone rnft = ILiquidSplitClone(_splitClone);
        uint256 totalUnclaimedRnfts = rnft.balanceOf(address(this), 0);
        (address claimerSplitClone,,,) = IROYALTY_POLICY_LAP.royaltyData(_claimerIpId);
        uint32 rnftAmountToTransfer = _ancestorsRoyalties[index];
        rnft.safeTransferFrom(address(this), claimerSplitClone, 0, rnftAmountToTransfer, "");

        // transfer the accrued tokens to the claimer split clone
        _claimAccruedTokens(rnftAmountToTransfer, totalUnclaimedRnfts, claimerSplitClone, _withdrawETH, _tokens);
    }

    /// @notice Claims the accrued tokens (if any)
    /// @param _rnftClaimAmount The amount of rnfts to claim
    /// @param _totalUnclaimedRnfts The total unclaimed rnfts
    /// @param _claimerSplitClone The claimer's split clone
    /// @param _withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param _tokens The ERC20 tokens to withdraw
    function _claimAccruedTokens(
        uint256 _rnftClaimAmount,
        uint256 _totalUnclaimedRnfts,
        address _claimerSplitClone,
        bool _withdrawETH,
        ERC20[] calldata _tokens
    ) internal {
        ILiquidSplitMain splitMain = ILiquidSplitMain(IROYALTY_POLICY_LAP.LIQUID_SPLIT_MAIN());

        if (_withdrawETH) {
            if (splitMain.getETHBalance(address(this)) != 0) revert Errors.AncestorsVaultLAP__ETHBalanceNotZero();

            uint256 ethBalance = address(this).balance;
            uint256 ethClaimAmount = (ethBalance * _rnftClaimAmount) / _totalUnclaimedRnfts;

            _safeTransferETH(_claimerSplitClone, ethClaimAmount);
        }

        for (uint256 i = 0; i < _tokens.length; ++i) {
            // When withdrawing ERC20, 0xSplits sets the value to 1 to have warm storage access.
            // But this still means 0 amount left. So, in the check below, we use `> 1`.
            if (splitMain.getERC20Balance(address(this), _tokens[i]) > 1) revert Errors.AncestorsVaultLAP__ERC20BalanceNotZero();

            IERC20 IToken = IERC20(_tokens[i]);
            uint256 tokenBalance = IToken.balanceOf(address(this));
            uint256 tokenClaimAmount = (tokenBalance * _rnftClaimAmount) / _totalUnclaimedRnfts;

            IToken.safeTransfer(_claimerSplitClone, tokenClaimAmount);
        }
    }

    /// @notice Allows to transfers ETH
    /// @param _to The address to transfer to
    /// @param _amount The amount to transfer
    function _safeTransferETH(address _to, uint256 _amount) internal {
        bool callStatus;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), _to, _amount, 0, 0, 0, 0)
        }

        if (!callStatus) revert Errors.RoyaltyPolicyLS__TransferFailed();
    }
}
 */