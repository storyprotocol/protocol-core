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

    struct LSRoyaltyData {
        address splitClone; // address of the liquid split clone contract for a given ipId
        address claimer; // address of the claimer contract for a given ipId
        uint32 royaltyStack; // royalty stack for a given ipId is the sum of the minRoyalty of all its parents
        // (number between 0 and 1000)
        uint32 minRoyalty; // minimum royalty the ipId will receive from its children and grandchildren
        // (number between 0 and 1000)
    }

    /// @notice Percentage scale - 1000 rnfts represents 100%
    uint32 public constant TOTAL_RNFT_SUPPLY = 1000;

    /// @notice RoyaltyModule address
    address public immutable ROYALTY_MODULE;

    /// @notice LicensingModule address
    address public immutable LICENSING_MODULE;

    /// @notice LiquidSplitFactory address
    address public immutable LIQUID_SPLIT_FACTORY;

    /// @notice LiquidSplitMain address
    address public immutable LIQUID_SPLIT_MAIN;

    /// @notice Links the ipId to its royalty data
    mapping(address ipId => LSRoyaltyData) public royaltyData;

    /// @notice Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != ROYALTY_MODULE) revert Errors.RoyaltyPolicyLS__NotRoyaltyModule();
        _;
    }

    /// @notice Constructor
    /// @param _royaltyModule Address of the RoyaltyModule contract
    /// @param _licensingModule Address of the LicensingModule contract
    /// @param _liquidSplitFactory Address of the LiquidSplitFactory contract
    /// @param _liquidSplitMain Address of the LiquidSplitMain contract
    constructor(
        address _royaltyModule,
        address _licensingModule,
        address _liquidSplitFactory,
        address _liquidSplitMain
    ) {
        if (_royaltyModule == address(0)) revert Errors.RoyaltyPolicyLS__ZeroRoyaltyModule();
        if (_licensingModule == address(0)) revert Errors.RoyaltyPolicyLS__ZeroLicensingModule();
        if (_liquidSplitFactory == address(0)) revert Errors.RoyaltyPolicyLS__ZeroLiquidSplitFactory();
        if (_liquidSplitMain == address(0)) revert Errors.RoyaltyPolicyLS__ZeroLiquidSplitMain();

        ROYALTY_MODULE = _royaltyModule;
        LICENSING_MODULE = _licensingModule;
        LIQUID_SPLIT_FACTORY = _liquidSplitFactory;
        LIQUID_SPLIT_MAIN = _liquidSplitMain;
    }

    /// @notice Initializes the royalty policy
    /// @param _ipId The ipId
    /// @param _parentIpIds The parent ipIds
    /// @param _data The data to initialize the policy
    function initPolicy(
        address _ipId,
        address[] calldata _parentIpIds,
        bytes calldata _data
    ) external onlyRoyaltyModule {
        uint32 minRoyalty = abi.decode(_data, (uint32));
        // root you can choose 0% but children have to choose at least 1%
        if (minRoyalty == 0 && _parentIpIds.length > 0) revert Errors.RoyaltyPolicyLS__ZeroMinRoyalty();
        // minRoyalty has to be a multiple of 1% and given that there are 1000 royalty nfts
        // then minRoyalty has to be a multiple of 10
        if (minRoyalty % 10 != 0) revert Errors.RoyaltyPolicyLS__InvalidMinRoyalty();

        // calculates the new royalty stack and checks if it is valid
        (uint32 royaltyStack, uint32 newRoyaltyStack) = _checkRoyaltyStackIsValid(_parentIpIds, minRoyalty);

        // deploy claimer if not root ip
        address claimer = address(this); // 0xSplit requires two addresses to allow a split so
        // for root ip address(this) is used as the second address
        if (_parentIpIds.length > 0) claimer = address(new LSClaimer(_ipId, LICENSING_MODULE, address(this)));

        // deploy split clone
        address splitClone = _deploySplitClone(_ipId, claimer, royaltyStack);

        royaltyData[_ipId] = LSRoyaltyData({
            splitClone: splitClone,
            claimer: claimer,
            royaltyStack: newRoyaltyStack,
            minRoyalty: minRoyalty
        });
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

    /// @notice Returns the minimum royalty the IPAccount expects from descendants
    /// @param _ipId The ipId
    function minRoyaltyFromDescendants(address _ipId) external view returns (uint32) {
        return royaltyData[_ipId].minRoyalty;
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

    /// @notice Checks if the royalty stack is valid
    /// @param _parentIpIds The parent ipIds
    /// @param _minRoyalty The minimum royalty
    /// @return royaltyStack The royalty stack
    ///         newRoyaltyStack The new royalty stack
    function _checkRoyaltyStackIsValid(
        address[] calldata _parentIpIds,
        uint32 _minRoyalty
    ) internal view returns (uint32, uint32) {
        // the loop below is limited to a length of 100 parents
        // given the minimum royalty step of 1% and a cap of 100%
        uint32 royaltyStack;
        for (uint32 i = 0; i < _parentIpIds.length; i++) {
            royaltyStack += royaltyData[_parentIpIds[i]].royaltyStack;
        }

        uint32 newRoyaltyStack = royaltyStack + _minRoyalty;
        if (newRoyaltyStack > TOTAL_RNFT_SUPPLY) revert Errors.RoyaltyPolicyLS__InvalidRoyaltyStack();

        return (royaltyStack, newRoyaltyStack);
    }

    /// @notice Deploys a liquid split clone contract
    /// @param _ipId The ipId
    /// @param _claimer The claimer address
    /// @param royaltyStack The number of rnfts that the ipId has to give to its parents and/or grandparents
    /// @return The address of the deployed liquid split clone contract
    function _deploySplitClone(address _ipId, address _claimer, uint32 royaltyStack) internal returns (address) {
        address[] memory accounts = new address[](2);
        accounts[0] = _ipId;
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
