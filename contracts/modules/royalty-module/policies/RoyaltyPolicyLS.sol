// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ILiquidSplitFactory} from "../../../../interfaces/modules/royalty-module/policies/ILiquidSplitFactory.sol";
import {IRoyaltyPolicy} from "../../../../interfaces/modules/royalty-module/policies/IRoyaltyPolicy.sol";
import {ILiquidSplitClone} from "../../../../interfaces/modules/royalty-module/policies/ILiquidSplitClone.sol";
import {ILiquidSplitMain} from "../../../../interfaces/modules/royalty-module/policies/ILiquidSplitMain.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {Errors} from "../../../lib/Errors.sol";

/// @title Liquid Split Royalty Policy
/// @notice The LiquidSplit royalty policy splits royalties in accordance with
///         the percentage of royalty NFTs owned by each account.
contract RoyaltyPolicyLS is IRoyaltyPolicy {
    using SafeERC20 for IERC20;

    /// @notice RoyaltyModule address
    address public immutable ROYALTY_MODULE;

    /// @notice LiquidSplitFactory address
    address public immutable LIQUID_SPLIT_FACTORY;

    /// @notice LiquidSplitMain address
    address public immutable LIQUID_SPLIT_MAIN;

    /// @notice Indicates the address of the LiquidSplitClone contract for a given ipId
    mapping(address ipId => address splitClone) public splitClones;

    /// @notice Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != ROYALTY_MODULE) revert Errors.RoyaltyPolicyLS__NotRoyaltyModule();
        _;
    }

    /// @notice Constructor
    /// @param _royaltyModule Address of the RoyaltyModule contract
    /// @param _liquidSplitFactory Address of the LiquidSplitFactory contract
    /// @param _liquidSplitMain Address of the LiquidSplitMain contract
    constructor(address _royaltyModule, address _liquidSplitFactory, address _liquidSplitMain) {
        if (_royaltyModule == address(0)) revert Errors.RoyaltyPolicyLS__ZeroRoyaltyModule();
        if (_liquidSplitFactory == address(0)) revert Errors.RoyaltyPolicyLS__ZeroLiquidSplitFactory();
        if (_liquidSplitMain == address(0)) revert Errors.RoyaltyPolicyLS__ZeroLiquidSplitMain();

        ROYALTY_MODULE = _royaltyModule;
        LIQUID_SPLIT_FACTORY = _liquidSplitFactory;
        LIQUID_SPLIT_MAIN = _liquidSplitMain;
    }

    /// @notice Initializes the royalty policy
    /// @param _ipId The ipId
    /// @param _data The data to initialize the policy
    function initPolicy(address _ipId, bytes calldata _data) external onlyRoyaltyModule {
        (address[] memory accounts, uint32[] memory initAllocations, uint32 distributorFee, address splitOwner) =
            abi.decode(_data, (address[], uint32[], uint32, address));

        // TODO: input validation: accounts & initAllocations - can we make up to 1000 parents with tx going through - if not alternative may be to create new contract to claim RNFTs
        // TODO: input validation: distributorFee
        // TODO: input validation: splitOwner

        address splitClone = ILiquidSplitFactory(LIQUID_SPLIT_FACTORY).createLiquidSplitClone(
            accounts, initAllocations, distributorFee, splitOwner
        );

        splitClones[_ipId] = splitClone;
    }

    /// @notice Distributes funds to the accounts in the LiquidSplitClone contract
    /// @param _ipId The ipId
    /// @param _token The token to distribute
    /// @param _accounts The accounts to distribute to
    /// @param _distributorAddress The distributor address
    function distributeFunds(address _ipId, address _token, address[] calldata _accounts, address _distributorAddress)
        external
    {
        ILiquidSplitClone(splitClones[_ipId]).distributeFunds(_token, _accounts, _distributorAddress);
    }

    /// @notice Claims the available royalties for a given account
    /// @param _account The account to claim for
    /// @param _withdrawETH The amount of ETH to withdraw
    /// @param _tokens The tokens to withdraw
    function claimRoyalties(address _account, uint256 _withdrawETH, ERC20[] calldata _tokens) external {
        ILiquidSplitMain(LIQUID_SPLIT_MAIN).withdraw(_account, _withdrawETH, _tokens);
    }

    /// @notice Allows to pay a royalty
    /// @param _caller The caller
    /// @param _ipId The ipId
    /// @param _token The token to pay
    /// @param _amount The amount to pay
    function onRoyaltyPayment(address _caller, address _ipId, address _token, uint256 _amount)
        external
        onlyRoyaltyModule
    {
        address destination = splitClones[_ipId];
        IERC20(_token).safeTransferFrom(_caller, destination, _amount);
    }
}
