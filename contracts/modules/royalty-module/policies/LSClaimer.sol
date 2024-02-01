// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// contracts
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { ILiquidSplitClone } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { IRoyaltyPolicyLS } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLS.sol";
import { ILiquidSplitMain } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { IClaimerLS } from "contracts/interfaces/modules/royalty/policies/IClaimerLS.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Liquid Split Claimer
/// @notice The liquid split claimer allows parents and grandparents to claim their share
///         the rnfts of their children and grandchildren along with any accrued royalties.
contract LSClaimer is IClaimerLS, ERC1155Holder, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The license registry interface
    ILicenseRegistry public immutable ILICENSE_REGISTRY;

    /// @notice The liquid split royalty policy interface
    IRoyaltyPolicyLS public immutable IROYALTY_POLICY_LS;

    /// @notice The ipId of the IP that this contract is associated with
    address public immutable IP_ID;

    /// @notice The paths between parent and children that have already been claimed
    mapping(bytes32 pathHash => bool) public claimedPaths;

    /// @notice Constructor
    /// @param _ipId The ipId of the IP that this contract is associated with
    /// @param _licenseRegistry The license registry address
    /// @param _royaltyPolicyLS The liquid split royalty policy address
    constructor(address _ipId, address _licenseRegistry, address _royaltyPolicyLS) {
        if (_ipId == address(0)) revert Errors.LSClaimer__ZeroIpId();
        if (_licenseRegistry == address(0)) revert Errors.LSClaimer__ZeroLicenseRegistry();
        if (_royaltyPolicyLS == address(0)) revert Errors.LSClaimer__ZeroRoyaltyPolicyLS();

        IP_ID = _ipId;
        ILICENSE_REGISTRY = ILicenseRegistry(_licenseRegistry);
        IROYALTY_POLICY_LS = IRoyaltyPolicyLS(_royaltyPolicyLS);
    }

    /// @notice Allows an parent or grandparent ipId to claim their rnfts and accrued royalties
    /// @param _path The path between the IP_ID and the parent or grandparent ipId
    /// @param _claimerIpId The ipId of the claimer
    /// @param _withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param _tokens The ERC20 tokens to withdraw
    function claim(address[] calldata _path, address _claimerIpId, bool _withdrawETH, ERC20[] calldata _tokens) external nonReentrant {
        bytes32 pathHash = keccak256(abi.encodePacked(_path));
        if (claimedPaths[pathHash]) revert Errors.LSClaimer__AlreadyClaimed();

        // check if path is valid
        if (_path[0] != _claimerIpId) revert Errors.LSClaimer__InvalidPathFirstPosition();
        if (_path[_path.length - 1] != IP_ID) revert Errors.LSClaimer__InvalidPathLastPosition();
        _checkIfPathIsValid(_path);

        // claim rnfts
        (address rnftAddr,,,) = IROYALTY_POLICY_LS.royaltyData(IP_ID);
        ILiquidSplitClone rnft = ILiquidSplitClone(rnftAddr);
        uint256 totalUnclaimedRnfts = rnft.balanceOf(address(this), 0);
        (address claimerSplitClone,,,uint32 rnftClaimAmount) = IROYALTY_POLICY_LS.royaltyData(_claimerIpId);
        rnft.safeTransferFrom(address(this), claimerSplitClone, 0, rnftClaimAmount, ""); 

        // claim accrued tokens (if any)
        _claimAccruedTokens(rnftClaimAmount, totalUnclaimedRnfts, claimerSplitClone, _withdrawETH, _tokens);

        claimedPaths[pathHash] = true;

        emit Claimed(_path, _claimerIpId, _withdrawETH, _tokens);
    }

    /// @notice Checks if a claiming path is valid
    /// @param _path The path between the IP_ID and the parent or grandparent ipId
    function _checkIfPathIsValid(address[] calldata _path) internal view {
        // the loop below is limited to no more than 100 parents 
        // given the minimum royalty step of 1% and there is a cap of 100%
        for (uint256 i = 0; i < _path.length - 1; i++) {
           if(!ILICENSE_REGISTRY.isParent(_path[i], _path[i+1])) revert Errors.LSClaimer__InvalidPath();
        }
    }

    /// @notice Claims the accrued tokens (if any)
    /// @param _rnftClaimAmount The amount of rnfts to claim
    /// @param _totalUnclaimedRnfts The total unclaimed rnfts
    /// @param _claimerSplitClone The claimer's split clone
    /// @param _withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param _tokens The ERC20 tokens to withdraw
    function _claimAccruedTokens(uint256 _rnftClaimAmount, uint256 _totalUnclaimedRnfts, address _claimerSplitClone, bool _withdrawETH, ERC20[] calldata _tokens) internal {
        ILiquidSplitMain splitMain = ILiquidSplitMain(IROYALTY_POLICY_LS.LIQUID_SPLIT_MAIN());        

        if (_withdrawETH) {
            if (splitMain.getETHBalance(address(this)) != 0) revert Errors.LSClaimer__ETHBalanceNotZero();

            uint256 ethBalance = address(this).balance;
            uint256 ethClaimAmount = ethBalance * _rnftClaimAmount / _totalUnclaimedRnfts;

            _safeTransferETH(_claimerSplitClone, ethClaimAmount);
        }

        for (uint256 i = 0; i < _tokens.length; ++i) {
            if (splitMain.getERC20Balance(address(this), _tokens[i]) != 0) revert Errors.LSClaimer__ERC20BalanceNotZero();

            IERC20 IToken = IERC20(_tokens[i]);
            uint256 tokenBalance = IToken.balanceOf(address(this));
            uint256 tokenClaimAmount = tokenBalance * _rnftClaimAmount / _totalUnclaimedRnfts;

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