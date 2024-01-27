// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// contracts
import { ILiquidSplitClone } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { ILiquidSplitFactory } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitFactory.sol";
import { ILiquidSplitMain } from "contracts/interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { IRoyaltyPolicy } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { Errors } from "contracts/lib/Errors.sol";

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

    struct LSRoyaltyData {
        address splitClone; // Indicates the address of the LiquidSplitClone contract for a given ipId
        address claimer; // Indicates the address of the claimer contract for a given ipId
        uint32 royaltyStack; // Indicates the royalty stack for a given ipId
        uint32 minRoyalty; // Indicates the minimum royalty for a given ipId
    }

    /// @notice Links the ipId to its royalty data
    mapping(address ipId => LSRoyaltyData) public royaltyData;

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
        (address[] memory accounts, uint32[] memory initAllocations, uint256 minRoyalty) = abi.decode(
            _data,
            (address[], uint32[], uint256)
        );

        // TODO: input validation: accounts - parentsIds should be correctly passed in through the licensing contract so that we do not need to check them here
        // TODO: input validation: initAllocations

        // deploy claimer
        address claimer;
        // address[] memory accounts = new address[](2);
        // accounts[0] = _ipId;
        // accounts[1] = claimer;
        // uint32[] memory allocations = new uint32[](2);
        // allocations[0] = uint32(1000) - currentRoyaltyStack;
        // allocations[1] = currentRoyaltyStack;

        address splitClone = ILiquidSplitFactory(LIQUID_SPLIT_FACTORY).createLiquidSplitClone(
            accounts,
            initAllocations,
            0, // distributorFee
            address(0) // splitOwner
        );

        // verify final state - _verifyInitPolicyFinalState()
        // The loop below is bounded to 1000 max iterations otherwise
        // it will revert on the split clone creation
        /*         uint32 currentRoyaltyStack;
        for (uint32 i = 0; i < accounts.length; i++) {
            currentRoyaltyStack = royaltyData[accounts[i]].royaltyStack;
        } */
        // RNFT balance of ipId should be 1000 - royalty stack
        // RNFT balance of claimer should be royalty stack

        //splitClones[_ipId] = splitClone;
    }

    /// @notice Distributes funds to the accounts in the LiquidSplitClone contract
    /// @param _ipId The ipId
    /// @param _token The token to distribute
    /// @param _accounts The accounts to distribute to
    /// @param _distributorAddress The distributor address
    function distributeFunds(
        address _ipId,
        address _token,
        address[] calldata _accounts,
        address _distributorAddress
    ) external {
        ILiquidSplitClone(royaltyData[_ipId].splitClone).distributeFunds(_token, _accounts, _distributorAddress);
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
    function onRoyaltyPayment(
        address _caller,
        address _ipId,
        address _token,
        uint256 _amount
    ) external onlyRoyaltyModule {
        address destination = royaltyData[_ipId].splitClone;
        IERC20(_token).safeTransferFrom(_caller, destination, _amount);
    }
}
