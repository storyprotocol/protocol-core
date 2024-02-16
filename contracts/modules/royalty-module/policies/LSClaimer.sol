// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ILicensingModule } from "../../../interfaces/modules/licensing/ILicensingModule.sol";
import { ILiquidSplitClone } from "../../../interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { IRoyaltyPolicyLS } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLS.sol";
import { ILiquidSplitMain } from "../../../interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { ILSClaimer } from "../../../interfaces/modules/royalty/policies/ILSClaimer.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Liquid Split Claimer
/// @notice The liquid split claimer allows parents and grandparents to claim their share
///         the rnfts of their children and grandchildren along with any accrued royalties.
contract LSClaimer is ILSClaimer, ERC1155Holder, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Returns the licensing module.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice Returns the royalty policy.
    IRoyaltyPolicyLS public immutable ROYALTY_POLICY_LS;

    /// @notice Returns the ID of the IP asset with which this LSClaimer is associated.
    address public immutable IP_ID;

    /// @notice Returns if the path between an ancestor/parent IP and a child IP has been claimed.
    mapping(bytes32 pathHash => bool isClaimed) public claimedPaths;

    constructor(address ipId, address licensingModule, address royaltyPolicyLS) {
        if (ipId == address(0)) revert Errors.LSClaimer__ZeroIpId();
        if (licensingModule == address(0)) revert Errors.LSClaimer__ZeroLicensingModule();
        if (royaltyPolicyLS == address(0)) revert Errors.LSClaimer__ZeroRoyaltyPolicyLS();

        IP_ID = ipId;
        LICENSING_MODULE = ILicensingModule(licensingModule);
        ROYALTY_POLICY_LS = IRoyaltyPolicyLS(royaltyPolicyLS);
    }

    /// @notice Allows an ancestor/parent IP asset to claim its Royalty NFTs (RNFTs) and any accrued royalties.
    /// @param path The path from an ancestor IP to a child IP
    /// @param claimerIpId The ID of the claimer's IP asset
    /// @param withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param tokens The ERC20 tokens to withdraw
    function claim(
        address[] calldata path,
        address claimerIpId,
        bool withdrawETH,
        ERC20[] calldata tokens
    ) external nonReentrant {
        bytes32 pathHash = keccak256(abi.encodePacked(path));
        if (claimedPaths[pathHash]) revert Errors.LSClaimer__AlreadyClaimed();

        // check if path is valid
        if (path[0] != claimerIpId) revert Errors.LSClaimer__InvalidPathFirstPosition();
        if (path[path.length - 1] != IP_ID) revert Errors.LSClaimer__InvalidPathLastPosition();
        _checkIfPathIsValid(path);

        // claim rnfts
        (address rnftAddr, , , ) = ROYALTY_POLICY_LS.royaltyData(IP_ID);
        ILiquidSplitClone rnft = ILiquidSplitClone(rnftAddr);
        uint256 totalUnclaimedRnfts = rnft.balanceOf(address(this), 0);
        (address claimerSplitClone, , , uint32 rnftClaimAmount) = ROYALTY_POLICY_LS.royaltyData(claimerIpId);
        rnft.safeTransferFrom(address(this), claimerSplitClone, 0, rnftClaimAmount, "");

        // claim accrued tokens (if any)
        _claimAccruedTokens(rnftClaimAmount, totalUnclaimedRnfts, claimerSplitClone, withdrawETH, tokens);

        claimedPaths[pathHash] = true;

        emit Claimed(path, claimerIpId, withdrawETH, tokens);
    }

    /// @notice Checks if a claiming path is valid.
    /// @param path The path from an ancestor IP to a child IP
    function _checkIfPathIsValid(address[] calldata path) internal view {
        // the loop below is limited to no more than 100 parents
        // given the minimum royalty step of 1% and there is a cap of 100%
        for (uint256 i = 0; i < path.length - 1; i++) {
            if (!LICENSING_MODULE.isParent(path[i], path[i + 1])) revert Errors.LSClaimer__InvalidPath();
        }
    }

    /// @notice Claims the accrued tokens (if any).
    /// @param rnftClaimAmount The amount of rnfts to claim
    /// @param totalUnclaimedRnfts The total unclaimed rnfts
    /// @param claimerSplitClone The claimer's split clone
    /// @param withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param tokens The ERC20 tokens to withdraw
    function _claimAccruedTokens(
        uint256 rnftClaimAmount,
        uint256 totalUnclaimedRnfts,
        address claimerSplitClone,
        bool withdrawETH,
        ERC20[] calldata tokens
    ) internal {
        ILiquidSplitMain splitMain = ILiquidSplitMain(ROYALTY_POLICY_LS.LIQUID_SPLIT_MAIN());

        if (withdrawETH) {
            if (splitMain.getETHBalance(address(this)) != 0) revert Errors.LSClaimer__ETHBalanceNotZero();

            uint256 ethBalance = address(this).balance;
            uint256 ethClaimAmount = (ethBalance * rnftClaimAmount) / totalUnclaimedRnfts;

            _safeTransferETH(claimerSplitClone, ethClaimAmount);
        }

        for (uint256 i = 0; i < tokens.length; ++i) {
            // When withdrawing ERC20, 0xSplits sets the value to 1 to have warm storage access.
            // But this still means 0 amount left. So, in the check below, we use `> 1`.
            if (splitMain.getERC20Balance(address(this), tokens[i]) > 1) revert Errors.LSClaimer__ERC20BalanceNotZero();

            IERC20 IToken = IERC20(tokens[i]);
            uint256 tokenBalance = IToken.balanceOf(address(this));
            uint256 tokenClaimAmount = (tokenBalance * rnftClaimAmount) / totalUnclaimedRnfts;

            IToken.safeTransfer(claimerSplitClone, tokenClaimAmount);
        }
    }

    /// @notice Allows to transfers ETH.
    /// @param to The address to transfer to
    /// @param amount The amount to transfer
    function _safeTransferETH(address to, uint256 amount) internal {
        bool callStatus;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }

        if (!callStatus) revert Errors.RoyaltyPolicyLS__TransferFailed();
    }
}
