// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IAncestorsVaultLAP } from "../../../interfaces/modules/royalty/policies/IAncestorsVaultLAP.sol";
import { Governable } from "../../../../contracts/governance/Governable.sol";
import { IRoyaltyPolicyLAP } from "../../../interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { ArrayUtils } from "../../../lib/ArrayUtils.sol";
import { ILiquidSplitFactory } from "../../../interfaces/modules/royalty/policies/ILiquidSplitFactory.sol";
import { ILiquidSplitMain } from "../../../interfaces/modules/royalty/policies/ILiquidSplitMain.sol";
import { ILiquidSplitClone } from "../../../interfaces/modules/royalty/policies/ILiquidSplitClone.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Liquid Absolute Percentage Royalty Policy
/// @notice Defines the logic for splitting royalties for a given ipId using a liquid absolute percentage mechanism
contract RoyaltyPolicyLAP is IRoyaltyPolicyLAP, Governable, ERC1155Holder, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct LAPRoyaltyData {
        bool isUnlinkableToParents; // indicates if the ipId is unlinkable to new parents
        address splitClone; // address of the liquid split clone contract for a given ipId
        address ancestorsVault; // address of the ancestors vault contract for a given ipId
        uint32 royaltyStack; // royalty stack for a given ipId is the sum of the royalties to be paid to all its parents
        bytes32 ancestorsHash; // hash of the unique ancestors array
    }

    /// @notice Percentage scale - 1000 rnfts represents 100%
    uint32 public constant TOTAL_RNFT_SUPPLY = 1000;

    /// @notice Maximum number of parents
    uint256 public constant MAX_PARENTS = 2;

    /// @notice Maximum number of total ancestors
    // The IP derivative tree is limited to 14 ancestors
    // which represents 3 levels of a binary tree 14 = 2 + 4 + 8
    uint256 public constant MAX_ANCESTORS = 14;

    /// @notice RoyaltyModule address
    address public immutable ROYALTY_MODULE;

    /// @notice LicensingModule address
    address public immutable LICENSING_MODULE;

    /// @notice LiquidSplitFactory address
    address public immutable LIQUID_SPLIT_FACTORY;

    /// @notice LiquidSplitMain address
    address public immutable LIQUID_SPLIT_MAIN;

    /// @notice Ancestors vault implementation address
    address public ANCESTORS_VAULT_IMPL;

    /// @notice Links the ipId to its royalty data
    mapping(address ipId => LAPRoyaltyData) public royaltyData;

    /// @notice Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != ROYALTY_MODULE) revert Errors.RoyaltyPolicyLAP__NotRoyaltyModule();
        _;
    }

    /// @notice Constructor
    /// @param _royaltyModule Address of the RoyaltyModule contract
    /// @param _licensingModule Address of the LicensingModule contract
    /// @param _liquidSplitFactory Address of the LiquidSplitFactory contract
    /// @param _liquidSplitMain Address of the LiquidSplitMain contract
    /// @param _governance Address of the governance contract
    constructor(
        address _royaltyModule,
        address _licensingModule,
        address _liquidSplitFactory,
        address _liquidSplitMain,
        address _governance
    ) Governable(_governance) {
        if (_royaltyModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroRoyaltyModule();
        if (_licensingModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroLicensingModule();
        if (_liquidSplitFactory == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroLiquidSplitFactory();
        if (_liquidSplitMain == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroLiquidSplitMain();

        ROYALTY_MODULE = _royaltyModule;
        LICENSING_MODULE = _licensingModule;
        LIQUID_SPLIT_FACTORY = _liquidSplitFactory;
        LIQUID_SPLIT_MAIN = _liquidSplitMain;
    }

    /// @notice Set the ancestors vault implementation address
    /// @param _ancestorsVaultImpl The ancestors vault implementation address
    function setAncestorsVaultImplementation(address _ancestorsVaultImpl) external onlyProtocolAdmin {
        if (_ancestorsVaultImpl == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroAncestorsVaultImpl();
        if (ANCESTORS_VAULT_IMPL != address(0)) revert Errors.RoyaltyPolicyLAP__ImplementationAlreadySet();

        ANCESTORS_VAULT_IMPL = _ancestorsVaultImpl;
    }

    /// @notice Executes royalty related logic on minting a license
    /// @param _ipId The children ipId that is being linked to parents
    /// @param _licenseData The license data custom to each the royalty policy
    /// @param _externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address _ipId,
        bytes calldata _licenseData,
        bytes calldata _externalData
    ) external onlyRoyaltyModule {
        uint32 newLicenseRoyalty = abi.decode(_licenseData, (uint32));
        LAPRoyaltyData memory data = royaltyData[_ipId];

        if (data.royaltyStack + newLicenseRoyalty > TOTAL_RNFT_SUPPLY)
            revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        if (data.splitClone == address(0)) {
            // If the policy is already initialized, it means that the ipId setup is already done. If not, it means that
            // the license for this royalty policy is being minted for the first time parentIpIds are zero given that only
            // roots can call _initPolicy() for the first time in the function onLicenseMinting() while derivatives already
            // called _initPolicy() when linking to their parents with onLinkToParents() call.
            address[] memory rootParents = new address[](0);
            bytes[] memory rootParentRoyalties = new bytes[](0);
            _initPolicy(_ipId, rootParents, rootParentRoyalties, _externalData);
        } else {
            InitParams memory params = abi.decode(_externalData, (InitParams));
            // If the policy is already initialized and an ipId has the maximum number of ancestors
            // it can not have any derivative and therefore is not allowed to mint any license
            if (params.targetAncestors.length >= MAX_ANCESTORS) revert Errors.RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense();
            // the check below ensures that the ancestors hash is the same as the one stored in the royalty data
            // and that the targetAncestors passed in by the user matches the record stored in state on policy initialization
            if (
                keccak256(abi.encodePacked(params.targetAncestors, params.targetRoyaltyAmount)) !=
                royaltyData[_ipId].ancestorsHash
            ) revert Errors.RoyaltyPolicyLAP__InvalidAncestorsHash();
        }
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @param _ipId The children ipId that is being linked to parents
    /// @param _parentIpIds The selected parent ipIds
    /// @param _licenseData The license data custom to each the royalty policy
    /// @param _externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address _ipId,
        address[] calldata _parentIpIds,
        bytes[] memory _licenseData,
        bytes calldata _externalData
    ) external onlyRoyaltyModule {
        if (royaltyData[_ipId].isUnlinkableToParents) revert Errors.RoyaltyPolicyLAP__UnlinkableToParents();

        _initPolicy(_ipId, _parentIpIds, _licenseData, _externalData);
    }

    /// @notice Initializes the royalty policy
    /// @param _ipId The ipId
    /// @param _parentIpIds The selected parent ipIds
    /// @param _licenseData The license data custom to each the royalty policy
    /// @param _externalData The external data custom to each the royalty policy
    function _initPolicy(
        address _ipId,
        address[] memory _parentIpIds,
        bytes[] memory _licenseData,
        bytes calldata _externalData
    ) internal onlyRoyaltyModule {
        // decode license and external data
        InitParams memory params = abi.decode(_externalData, (InitParams));
        uint32[] memory parentRoyalties = new uint32[](_parentIpIds.length);
        for (uint256 i = 0; i < _parentIpIds.length; i++) {
            parentRoyalties[i] = abi.decode(_licenseData[i], (uint32));
        }

        if (params.targetAncestors.length > MAX_ANCESTORS) revert Errors.RoyaltyPolicyLAP__AboveAncestorsLimit();
        if (_parentIpIds.length > MAX_PARENTS) revert Errors.RoyaltyPolicyLAP__AboveParentLimit();

        // calculate new royalty stack
        uint32 royaltyStack = _checkAncestorsDataIsValid(_parentIpIds, parentRoyalties, params);

        // set the parents as unlinkable / loop limited to 2 parents
        for (uint256 i = 0; i < _parentIpIds.length; i++) {
            royaltyData[_parentIpIds[i]].isUnlinkableToParents = true;
        }

        // deploy ancestors vault if not root ip
        // 0xSplit requires two addresses to allow a split so for root ip address(this) is used as the second address
        address ancestorsVault = _parentIpIds.length > 0 ? Clones.clone(ANCESTORS_VAULT_IMPL) : address(this);

        // deploy split clone
        address splitClone = _deploySplitClone(_ipId, ancestorsVault, royaltyStack);

        royaltyData[_ipId] = LAPRoyaltyData({
            // whether calling via minting license or linking to parents the ipId becomes unlinkable
            isUnlinkableToParents: true,
            splitClone: splitClone,
            ancestorsVault: ancestorsVault,
            royaltyStack: royaltyStack,
            ancestorsHash: keccak256(abi.encodePacked(params.targetAncestors, params.targetRoyaltyAmount))
        });

        emit PolicyInitialized(
            _ipId,
            splitClone,
            ancestorsVault,
            royaltyStack,
            params.targetAncestors,
            params.targetRoyaltyAmount
        );
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

    /// @notice Distributes funds internally so that accounts holding the royalty nfts at distribution moment can claim
    /// afterwards
    /// @param _ipId The ipId
    /// @param _token The token to distribute
    /// @param _accounts The accounts to distribute to
    /// @param _distributorAddress The distributor address
    function distributeIpPoolFunds(
        address _ipId,
        address _token,
        address[] calldata _accounts,
        address _distributorAddress
    ) external {
        ILiquidSplitClone(royaltyData[_ipId].splitClone).distributeFunds(_token, _accounts, _distributorAddress);
    }

    /// @notice Claims the available royalties for a given address
    /// @param _account The account to claim for
    /// @param _withdrawETH The amount of ETH to withdraw
    /// @param _tokens The tokens to withdraw
    function claimFromIpPool(address _account, uint256 _withdrawETH, ERC20[] calldata _tokens) external {
        ILiquidSplitMain(LIQUID_SPLIT_MAIN).withdraw(_account, _withdrawETH, _tokens);
    }

    /// @notice Claims the available royalties for a given address that holds all the royalty nfts of an ipId
    /// @param _ipId The ipId
    /// @param _withdrawETH The amount of ETH to withdraw
    /// @param _token The token to withdraw
    function claimFromIpPoolAsTotalRnftOwner(
        address _ipId,
        uint256 _withdrawETH,
        address _token
    ) external nonReentrant {
        ILiquidSplitClone splitClone = ILiquidSplitClone(royaltyData[_ipId].splitClone);
        ILiquidSplitMain splitMain = ILiquidSplitMain(LIQUID_SPLIT_MAIN);

        if (splitClone.balanceOf(msg.sender, 0) < TOTAL_RNFT_SUPPLY) revert Errors.RoyaltyPolicyLAP__NotFullOwnership();

        splitClone.safeTransferFrom(msg.sender, address(this), 0, 1, "0x0");

        address[] memory accounts = new address[](2);
        accounts[0] = msg.sender;
        accounts[1] = address(this);

        ERC20[] memory token = _withdrawETH != 0 ? new ERC20[](0) : new ERC20[](1);

        if (_withdrawETH != 0) {
            splitClone.distributeFunds(address(0), accounts, address(0));
        } else {
            splitClone.distributeFunds(_token, accounts, address(0));
            token[0] = ERC20(_token);
        }

        splitMain.withdraw(msg.sender, _withdrawETH, token);
        splitMain.withdraw(address(this), _withdrawETH, token);

        splitClone.safeTransferFrom(address(this), msg.sender, 0, 1, "0x0");

        if (_withdrawETH != 0) {
            _safeTransferETH(msg.sender, address(this).balance);
        } else {
            IERC20(_token).safeTransfer(msg.sender, IERC20(_token).balanceOf(address(this)));
        }
    }

    /// @notice Claims all available royalty nfts and accrued royalties for an ancestor of a given ipId
    /// @param _ipId The ipId
    /// @param _claimerIpId The claimer ipId
    /// @param _ancestors The ancestors of the IP
    /// @param _ancestorsRoyalties The royalties of the ancestors
    /// @param _withdrawETH Indicates if the claimer wants to withdraw ETH
    /// @param _tokens The ERC20 tokens to withdraw
    function claimFromAncestorsVault(
        address _ipId,
        address _claimerIpId,
        address[] calldata _ancestors,
        uint32[] calldata _ancestorsRoyalties,
        bool _withdrawETH,
        ERC20[] calldata _tokens
    ) external {
        IAncestorsVaultLAP(royaltyData[_ipId].ancestorsVault).claim(
            _ipId,
            _claimerIpId,
            _ancestors,
            _ancestorsRoyalties,
            _withdrawETH,
            _tokens
        );
    }

    receive() external payable {}

    /// @notice Checks if the ancestors data is valid
    /// @param _parentIpIds The parent ipIds
    /// @param _parentRoyalties The parent royalties
    /// @param _params The init params
    /// @return newRoyaltyStack The new royalty stack
    function _checkAncestorsDataIsValid(
        address[] memory _parentIpIds,
        uint32[] memory _parentRoyalties,
        InitParams memory _params
    ) internal view returns (uint32) {
        if (_params.targetRoyaltyAmount.length != _params.targetAncestors.length)
            revert Errors.RoyaltyPolicyLAP__InvalidRoyaltyAmountLength();
        if (_parentRoyalties.length != _parentIpIds.length)
            revert Errors.RoyaltyPolicyLAP__InvalidParentRoyaltiesLength();

        (
            address[] memory newAncestors,
            uint32[] memory newAncestorsRoyalty,
            uint32 newAncestorsCount,
            uint32 newRoyaltyStack
        ) = _getExpectedOutputs(_parentIpIds, _parentRoyalties, _params);

        if (_params.targetAncestors.length != newAncestorsCount)
            revert Errors.RoyaltyPolicyLAP__InvalidAncestorsLength();
        if (newRoyaltyStack > TOTAL_RNFT_SUPPLY) revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        for (uint256 k = 0; k < newAncestorsCount; k++) {
            if (_params.targetAncestors[k] != newAncestors[k]) revert Errors.RoyaltyPolicyLAP__InvalidAncestors();
            if (_params.targetRoyaltyAmount[k] != newAncestorsRoyalty[k])
                revert Errors.RoyaltyPolicyLAP__InvalidAncestorsRoyalty();
        }

        return newRoyaltyStack;
    }

    /// @notice Gets the expected outputs for the ancestors and ancestors royalties
    /// @param _parentIpIds The parent ipIds
    /// @param _parentRoyalties The parent royalties
    /// @param _params The init params
    /// @return newAncestors The new ancestors
    /// @return newAncestorsRoyalty The new ancestors royalty
    /// @return ancestorsCount The number of ancestors
    /// @return royaltyStack The royalty stack
    // solhint-disable-next-line code-complexity
    function _getExpectedOutputs(
        address[] memory _parentIpIds,
        uint32[] memory _parentRoyalties,
        InitParams memory _params
    )
        internal
        view
        returns (
            address[] memory newAncestors,
            uint32[] memory newAncestorsRoyalty,
            uint32 ancestorsCount,
            uint32 royaltyStack
        )
    {
        newAncestorsRoyalty = new uint32[](_params.targetRoyaltyAmount.length);
        newAncestors = new address[](_params.targetAncestors.length);

        for (uint256 i = 0; i < _parentIpIds.length; i++) {
            if (i == 0) {
                newAncestors[ancestorsCount] = _parentIpIds[i];
                newAncestorsRoyalty[ancestorsCount] += _parentRoyalties[i];
                royaltyStack += _parentRoyalties[i];
                ancestorsCount++;
            } else if (i == 1) {
                (uint256 index, bool isIn) = ArrayUtils.indexOf(newAncestors, _parentIpIds[i]);
                if (!isIn) {
                    newAncestors[ancestorsCount] = _parentIpIds[i];
                    newAncestorsRoyalty[ancestorsCount] += _parentRoyalties[i];
                    royaltyStack += _parentRoyalties[i];
                    ancestorsCount++;
                } else {
                    newAncestorsRoyalty[index] += _parentRoyalties[i];
                    royaltyStack += _parentRoyalties[i];
                }
            }

            address[] memory parentAncestors = i == 0 ? _params.parentAncestors1 : _params.parentAncestors2;
            uint32[] memory parentAncestorsRoyalties = i == 0
                ? _params.parentAncestorsRoyalties1
                : _params.parentAncestorsRoyalties2;
            if (
                keccak256(abi.encodePacked(parentAncestors, parentAncestorsRoyalties)) !=
                royaltyData[_parentIpIds[i]].ancestorsHash
            ) revert Errors.RoyaltyPolicyLAP__InvalidAncestorsHash();

            for (uint256 j = 0; j < parentAncestors.length; j++) {
                if (i == 0) {
                    newAncestors[ancestorsCount] = parentAncestors[j];
                    newAncestorsRoyalty[ancestorsCount] += parentAncestorsRoyalties[j];
                    royaltyStack += parentAncestorsRoyalties[j];
                    ancestorsCount++;
                } else if (i == 1) {
                    (uint256 index, bool isIn) = ArrayUtils.indexOf(newAncestors, parentAncestors[j]);
                    if (!isIn) {
                        newAncestors[ancestorsCount] = parentAncestors[j];
                        newAncestorsRoyalty[ancestorsCount] += parentAncestorsRoyalties[j];
                        royaltyStack += parentAncestorsRoyalties[j];
                        ancestorsCount++;
                    } else {
                        newAncestorsRoyalty[index] += parentAncestorsRoyalties[j];
                        royaltyStack += parentAncestorsRoyalties[j];
                    }
                }
            }
        }
    }

    /// @notice Deploys a liquid split clone contract
    /// @param _ipId The ipId
    /// @param _ancestorsVault The ancestors vault address
    /// @param _royaltyStack The number of rnfts that the ipId has to give to its parents and/or grandparents
    /// @return The address of the deployed liquid split clone contract
    function _deploySplitClone(
        address _ipId,
        address _ancestorsVault,
        uint32 _royaltyStack
    ) internal returns (address) {
        address[] memory accounts = new address[](2);
        accounts[0] = _ipId;
        accounts[1] = _ancestorsVault;

        uint32[] memory initAllocations = new uint32[](2);
        initAllocations[0] = TOTAL_RNFT_SUPPLY - _royaltyStack;
        initAllocations[1] = _royaltyStack;

        address splitClone = ILiquidSplitFactory(LIQUID_SPLIT_FACTORY).createLiquidSplitClone(
            accounts,
            initAllocations,
            0, // distributorFee
            address(0) // splitOwner
        );

        return splitClone;
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

        if (!callStatus) revert Errors.RoyaltyPolicyLAP__TransferFailed();
    }
}
