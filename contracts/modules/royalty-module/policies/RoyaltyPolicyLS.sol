// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import { LSClaimer } from "../../../modules/royalty-module/policies/LSClaimer.sol";
import { ILiquidSplitClone } from "../../../interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { ILiquidSplitFactory } from "../../../interfaces/modules/royalty/policies/ILiquidSplitFactory.sol";
import { ILiquidSplitMain } from "../../../interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { IRoyaltyPolicyLS } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLS.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Liquid Split Royalty Policy
/// @notice The LiquidSplit royalty policy splits royalties in accordance with
///         the percentage of royalty NFTs owned by each account.
contract RoyaltyPolicyLS is IRoyaltyPolicyLS, ERC1155Holder {
    using SafeERC20 for IERC20;

    /// @notice Percentage scale - 1000 rnfts represents 100%.
    uint32 public constant TOTAL_RNFT_SUPPLY = 1000;

    /// @notice Returns the royalty module address
    address public immutable ROYALTY_MODULE;

    /// @notice Returns the licensing module address
    address public immutable LICENSING_MODULE;

    /// @notice Returns the liquid split factory address
    address public immutable LIQUID_SPLIT_FACTORY;

    /// @notice Returns the liquid split main address
    address public immutable LIQUID_SPLIT_MAIN;

    /// @notice Returns the royalty data for a given IP asset
    mapping(address ipId => LSRoyaltyData) public royaltyData;

    /// @notice Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != ROYALTY_MODULE) revert Errors.RoyaltyPolicyLS__NotRoyaltyModule();
        _;
    }

    constructor(address royaltyModule, address licensingModule, address liquidSplitFactory, address liquidSplitMain) {
        if (royaltyModule == address(0)) revert Errors.RoyaltyPolicyLS__ZeroRoyaltyModule();
        if (licensingModule == address(0)) revert Errors.RoyaltyPolicyLS__ZeroLicensingModule();
        if (liquidSplitFactory == address(0)) revert Errors.RoyaltyPolicyLS__ZeroLiquidSplitFactory();
        if (liquidSplitMain == address(0)) revert Errors.RoyaltyPolicyLS__ZeroLiquidSplitMain();

        ROYALTY_MODULE = royaltyModule;
        LICENSING_MODULE = licensingModule;
        LIQUID_SPLIT_FACTORY = liquidSplitFactory;
        LIQUID_SPLIT_MAIN = liquidSplitMain;
    }

    /// @notice Initializes the royalty policy for the given IP asset
    /// @dev Enforced to be only callable by the royalty module
    /// @param ipId The ID of the IP asset
    /// @param parentIpIds List of parent IP asset IDs
    /// @param data The encoded data that will be used by the royalty policy
    function initPolicy(address ipId, address[] calldata parentIpIds, bytes calldata data) external onlyRoyaltyModule {
        uint32 minRoyalty = abi.decode(data, (uint32));
        // root you can choose 0% but children have to choose at least 1%
        if (minRoyalty == 0 && parentIpIds.length > 0) revert Errors.RoyaltyPolicyLS__ZeroMinRoyalty();
        // minRoyalty has to be a multiple of 1% and given that there are 1000 royalty nfts
        // then minRoyalty has to be a multiple of 10
        if (minRoyalty % 10 != 0) revert Errors.RoyaltyPolicyLS__InvalidMinRoyalty();

        // calculates the new royalty stack and checks if it is valid
        (uint32 royaltyStack, uint32 newRoyaltyStack) = _checkRoyaltyStackIsValid(parentIpIds, minRoyalty);

        // deploy claimer if not root ip
        address claimer = address(this); // 0xSplit requires two addresses to allow a split so
        // for root ip address(this) is used as the second address
        if (parentIpIds.length > 0) claimer = address(new LSClaimer(ipId, LICENSING_MODULE, address(this)));

        // deploy split clone
        address splitClone = _deploySplitClone(ipId, claimer, royaltyStack);

        royaltyData[ipId] = LSRoyaltyData({
            splitClone: splitClone,
            claimer: claimer,
            royaltyStack: newRoyaltyStack,
            minRoyalty: minRoyalty
        });
    }

    /// @notice Transfers royalty payment according to an IP asset's royalty policy data. Triggered on royalty payment
    /// from the royalty module.
    /// @dev Enforced to be only callable by the royalty module
    /// @param caller The caller to pay the royalty
    /// @param ipId The ID of the IP asset to find the royalty policy data
    /// @param token The ERC20 token to pay
    /// @param amount The token amount to pay to the splitClone defined in the royalty policy data of ipId
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external onlyRoyaltyModule {
        address destination = royaltyData[ipId].splitClone;
        IERC20(token).safeTransferFrom(caller, destination, amount);
    }

    // TODO: deprecate
    /// @notice Returns the minimum royalty the IPAccount expects from descendants
    /// @param ipId The ipId
    /// @return minRoyalty The minimum royalty the IPAccount expects from descendants
    function minRoyaltyFromDescendants(address ipId) external view override returns (uint32) {
        return royaltyData[ipId].minRoyalty;
    }

    /// @notice Distributes funds to the accounts in the LiquidSplitClone contract
    /// @param ipId The ID of the IP asset
    /// @param token The ERC20 token to distribute
    /// @param accounts The accounts to distribute to
    /// @param distributorAddress The distributor address
    function distributeFunds(
        address ipId,
        address token,
        address[] calldata accounts,
        address distributorAddress
    ) external {
        ILiquidSplitClone(royaltyData[ipId].splitClone).distributeFunds(token, accounts, distributorAddress);
    }

    /// @notice Claims the available royalties for a given IP account
    /// @param account The IP account to claim for
    /// @param withdrawETH The amount of ETH to withdraw
    /// @param tokens The tokens to withdraw
    function claimRoyalties(address account, uint256 withdrawETH, ERC20[] calldata tokens) external {
        ILiquidSplitMain(LIQUID_SPLIT_MAIN).withdraw(account, withdrawETH, tokens);
    }

    /// @notice Checks if the royalty stack is valid.
    /// @param parentIpIds List of parent IP asset IDs
    /// @param _minRoyalty The minimum royalty
    /// @return royaltyStack The current royalty stack
    /// @return newRoyaltyStack The new royalty stack
    function _checkRoyaltyStackIsValid(
        address[] calldata parentIpIds,
        uint32 _minRoyalty
    ) internal view returns (uint32, uint32) {
        // the loop below is limited to a length of 100 parents
        // given the minimum royalty step of 1% and a cap of 100%
        uint32 royaltyStack;
        for (uint32 i = 0; i < parentIpIds.length; i++) {
            royaltyStack += royaltyData[parentIpIds[i]].royaltyStack;
        }

        uint32 newRoyaltyStack = royaltyStack + _minRoyalty;
        if (newRoyaltyStack > TOTAL_RNFT_SUPPLY) revert Errors.RoyaltyPolicyLS__InvalidRoyaltyStack();

        return (royaltyStack, newRoyaltyStack);
    }

    /// @notice Deploys a liquid split clone contract for a given IP asset.
    /// @param ipId The ID of the IP asset
    /// @param _claimer The claimer address associated with the IP asset
    /// @param royaltyStack The number of Royalty NFTs that this IP asset has to give to its ancestors
    /// @return splitClone The address of the deployed liquid split clone contract for this IP asset
    function _deploySplitClone(address ipId, address _claimer, uint32 royaltyStack) internal returns (address) {
        address[] memory accounts = new address[](2);
        accounts[0] = ipId;
        accounts[1] = _claimer;

        uint32[] memory initAllocations = new uint32[](2);
        initAllocations[0] = TOTAL_RNFT_SUPPLY - royaltyStack;
        initAllocations[1] = royaltyStack;

        address splitClone = ILiquidSplitFactory(LIQUID_SPLIT_FACTORY).createLiquidSplitClone(
            accounts,
            initAllocations,
            0, // distributorFee
            address(0) // splitOwner
        );

        return splitClone;
    }
}
