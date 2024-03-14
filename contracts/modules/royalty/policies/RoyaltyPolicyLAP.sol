// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

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

    /// @notice The state data of the LAP royalty policy
    /// @param isUnlinkableToParents Indicates if the ipId is unlinkable to new parents
    /// @param splitClone The address of the liquid split clone contract for a given ipId
    /// @param ancestorsVault The address of the ancestors vault contract for a given ipId
    /// @param royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @param ancestorsAddresses The ancestors addresses array
    /// @param ancestorsRoyalties The ancestors royalties array
    struct LAPRoyaltyData {
        bool isUnlinkableToParents;
        address splitClone;
        address ancestorsVault;
        uint32 royaltyStack;
        address[] ancestorsAddresses;
        uint32[] ancestorsRoyalties;
    }

    /// @notice Returns the percentage scale - 1000 rnfts represents 100%
    uint32 public constant TOTAL_RNFT_SUPPLY = 1000;

    /// @notice Returns the maximum number of parents
    uint256 public constant MAX_PARENTS = 2;

    /// @notice Returns the maximum number of total ancestors.
    /// @dev The IP derivative tree is limited to 14 ancestors, which represents 3 levels of a binary tree 14 = 2+4+8
    uint256 public constant MAX_ANCESTORS = 14;

    /// @notice Returns the RoyaltyModule address
    address public immutable ROYALTY_MODULE;

    /// @notice Returns the LicensingModule address
    address public immutable LICENSING_MODULE;

    /// @notice Returns the 0xSplits LiquidSplitFactory address
    address public immutable LIQUID_SPLIT_FACTORY;

    /// @notice Returns the 0xSplits LiquidSplitMain address
    address public immutable LIQUID_SPLIT_MAIN;

    /// @notice Returns the Ancestors Vault Implementation address
    address public ANCESTORS_VAULT_IMPL;

    /// @notice Returns the royalty data for a given IP asset
    mapping(address ipId => LAPRoyaltyData) public royaltyData;

    /// @dev Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != ROYALTY_MODULE) revert Errors.RoyaltyPolicyLAP__NotRoyaltyModule();
        _;
    }

    constructor(
        address royaltyModule,
        address licensingModule,
        address liquidSplitFactory,
        address liquidSplitMain,
        address governance
    ) Governable(governance) {
        if (royaltyModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroRoyaltyModule();
        if (licensingModule == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroLicensingModule();
        if (liquidSplitFactory == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroLiquidSplitFactory();
        if (liquidSplitMain == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroLiquidSplitMain();

        ROYALTY_MODULE = royaltyModule;
        LICENSING_MODULE = licensingModule;
        LIQUID_SPLIT_FACTORY = liquidSplitFactory;
        LIQUID_SPLIT_MAIN = liquidSplitMain;
    }

    receive() external payable {}

    /// @dev Set the ancestors vault implementation address
    /// @dev Enforced to be only callable by the protocol admin in governance
    /// @param ancestorsVaultImpl The ancestors vault implementation address
    function setAncestorsVaultImplementation(address ancestorsVaultImpl) external onlyProtocolAdmin {
        if (ancestorsVaultImpl == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroAncestorsVaultImpl();
        if (ANCESTORS_VAULT_IMPL != address(0)) revert Errors.RoyaltyPolicyLAP__ImplementationAlreadySet();

        ANCESTORS_VAULT_IMPL = ancestorsVaultImpl;
    }

    /// @notice Executes royalty related logic on minting a license
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The ipId whose license is being minted (licensor)
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address ipId,
        bytes calldata licenseData,
        bytes calldata externalData
    ) external onlyRoyaltyModule {
        uint32 newLicenseRoyalty = abi.decode(licenseData, (uint32));
        LAPRoyaltyData memory data = royaltyData[ipId];

        if (data.royaltyStack + newLicenseRoyalty > TOTAL_RNFT_SUPPLY)
            revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        if (data.splitClone == address(0)) {
            // If the policy is already initialized, it means that the ipId setup is already done. If not, it means
            // that the license for this royalty policy is being minted for the first time parentIpIds are zero given
            // that only roots can call _initPolicy() for the first time in the function onLicenseMinting() while
            // derivatives already
            // called _initPolicy() when linking to their parents with onLinkToParents() call.
            address[] memory rootParents = new address[](0);
            bytes[] memory rootParentRoyalties = new bytes[](0);
            _initPolicy(ipId, rootParents, rootParentRoyalties);
        } else {
            // If the policy is already initialized and an ipId has the maximum number of ancestors
            // it can not have any derivative and therefore is not allowed to mint any license
            if (royaltyData[ipId].ancestorsAddresses.length >= MAX_ANCESTORS)
                revert Errors.RoyaltyPolicyLAP__LastPositionNotAbleToMintLicense();
        }
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The children ipId that is being linked to parents
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param licenseData The license data custom to each the royalty policy
    /// @param externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external onlyRoyaltyModule {
        if (royaltyData[ipId].isUnlinkableToParents) revert Errors.RoyaltyPolicyLAP__UnlinkableToParents();

        _initPolicy(ipId, parentIpIds, licenseData);
    }

    /// @dev Initializes the royalty policy for a given IP asset.
    /// @dev Enforced to be only callable by RoyaltyModule
    /// @param ipId The to initialize the policy for
    /// @param parentIpIds The parent ipIds that the children ipId is being linked to (if any)
    /// @param licenseData The license data custom to each the royalty policy
    function _initPolicy(
        address ipId,
        address[] memory parentIpIds,
        bytes[] memory licenseData
    ) internal onlyRoyaltyModule {
        // decode license data
        uint32[] memory parentRoyalties = new uint32[](parentIpIds.length);
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            parentRoyalties[i] = abi.decode(licenseData[i], (uint32));
        }

        if (parentIpIds.length > MAX_PARENTS) revert Errors.RoyaltyPolicyLAP__AboveParentLimit();

        // calculate new royalty stack
        (
            uint32 royaltyStack,
            address[] memory newAncestors,
            uint32[] memory newAncestorsRoyalties
        ) = _getNewAncestorsData(parentIpIds, parentRoyalties);

        // set the parents as unlinkable / loop limited to 2 parents
        for (uint256 i = 0; i < parentIpIds.length; i++) {
            royaltyData[parentIpIds[i]].isUnlinkableToParents = true;
        }

        // deploy ancestors vault if not root ip
        // 0xSplit requires two addresses to allow a split so for root ip address(this) is used as the second address
        address ancestorsVault = parentIpIds.length > 0 ? Clones.clone(ANCESTORS_VAULT_IMPL) : address(this);

        // deploy split clone
        address splitClone = _deploySplitClone(ipId, ancestorsVault, royaltyStack);

        // ancestorsVault is adjusted as address(this) was just used for the split clone deployment
        ancestorsVault = ancestorsVault == address(this) ? address(0) : ancestorsVault;

        royaltyData[ipId] = LAPRoyaltyData({
            // whether calling via minting license or linking to parents the ipId becomes unlinkable
            isUnlinkableToParents: true,
            splitClone: splitClone,
            ancestorsVault: ancestorsVault,
            royaltyStack: royaltyStack,
            ancestorsAddresses: newAncestors,
            ancestorsRoyalties: newAncestorsRoyalties
        });

        emit PolicyInitialized(ipId, splitClone, ancestorsVault, royaltyStack, newAncestors, newAncestorsRoyalties);
    }

    /// @notice Allows the caller to pay royalties to the given IP asset
    /// @param caller The caller is the address from which funds will transferred from
    /// @param ipId The ipId of the receiver of the royalties
    /// @param token The token to pay
    /// @param amount The amount to pay
    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external onlyRoyaltyModule {
        address destination = royaltyData[ipId].splitClone;
        IERC20(token).safeTransferFrom(caller, destination, amount);
    }

    /// @notice Distributes funds internally so that accounts holding the royalty nfts at distribution moment can
    /// claim afterwards
    /// @dev This call will revert if the caller holds all the royalty nfts of the ipId - in that case can call
    /// claimFromIpPoolAsTotalRnftOwner() instead
    /// @param ipId The ipId whose received funds will be distributed
    /// @param token The token to distribute
    /// @param accounts The accounts to distribute to
    /// @param distributorAddress The distributor address (if any)
    function distributeIpPoolFunds(
        address ipId,
        address token,
        address[] calldata accounts,
        address distributorAddress
    ) external {
        ILiquidSplitClone(royaltyData[ipId].splitClone).distributeFunds(token, accounts, distributorAddress);
    }

    /// @notice Claims the available royalties for a given address
    /// @dev If there are no funds available in split main contract but there are funds in the split clone contract
    /// then a distributeIpPoolFunds() call should precede this call
    /// @param account The account to claim for
    /// @param tokens The tokens to withdraw
    function claimFromIpPool(address account, ERC20[] calldata tokens) external {
        ILiquidSplitMain(LIQUID_SPLIT_MAIN).withdraw(account, 0, tokens);
    }

    /// @notice Claims the available royalties for a given address that holds all the royalty nfts of an ipId
    /// @dev This call will revert if the caller does not hold all the royalty nfts of the ipId
    /// @param ipId The ipId whose received funds will be distributed
    /// @param token The token to withdraw
    function claimFromIpPoolAsTotalRnftOwner(address ipId, address token) external nonReentrant {
        ILiquidSplitClone splitClone = ILiquidSplitClone(royaltyData[ipId].splitClone);
        ILiquidSplitMain splitMain = ILiquidSplitMain(LIQUID_SPLIT_MAIN);

        if (splitClone.balanceOf(msg.sender, 0) < TOTAL_RNFT_SUPPLY) revert Errors.RoyaltyPolicyLAP__NotFullOwnership();

        splitClone.safeTransferFrom(msg.sender, address(this), 0, 1, "0x0");

        address[] memory accounts = new address[](2);
        accounts[0] = msg.sender;
        accounts[1] = address(this);

        ERC20[] memory tokens = new ERC20[](1);

        splitClone.distributeFunds(token, accounts, address(0));
        tokens[0] = ERC20(token);

        splitMain.withdraw(msg.sender, 0, tokens);
        splitMain.withdraw(address(this), 0, tokens);

        splitClone.safeTransferFrom(address(this), msg.sender, 0, 1, "0x0");

        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /// @notice Claims all available royalty nfts and accrued royalties for an ancestor of a given ipId
    /// @param ipId The ipId of the ancestors vault to claim from
    /// @param claimerIpId The claimer ipId is the ancestor address that wants to claim
    /// @param tokens The ERC20 tokens to withdraw
    function claimFromAncestorsVault(address ipId, address claimerIpId, ERC20[] calldata tokens) external {
        IAncestorsVaultLAP(royaltyData[ipId].ancestorsVault).claim(ipId, claimerIpId, tokens);
    }

    /// @dev Gets the new ancestors data
    /// @param parentIpIds The parent ipIds
    /// @param parentRoyalties The parent royalties
    /// @return newRoyaltyStack The new royalty stack
    /// @return newAncestors The new ancestors
    /// @return newAncestorsRoyalty The new ancestors royalty
    function _getNewAncestorsData(
        address[] memory parentIpIds,
        uint32[] memory parentRoyalties
    ) internal view returns (uint32, address[] memory, uint32[] memory) {
        if (parentRoyalties.length != parentIpIds.length)
            revert Errors.RoyaltyPolicyLAP__InvalidParentRoyaltiesLength();

        (
            address[] memory newAncestors,
            uint32[] memory newAncestorsRoyalty,
            uint32 newAncestorsCount,
            uint32 newRoyaltyStack
        ) = _getExpectedOutputs(parentIpIds, parentRoyalties);

        if (newAncestorsCount > MAX_ANCESTORS) revert Errors.RoyaltyPolicyLAP__AboveAncestorsLimit();
        if (newRoyaltyStack > TOTAL_RNFT_SUPPLY) revert Errors.RoyaltyPolicyLAP__AboveRoyaltyStackLimit();

        return (newRoyaltyStack, newAncestors, newAncestorsRoyalty);
    }

    /// @dev Gets the expected outputs for the ancestors and ancestors royalties
    /// @param parentIpIds The parent ipIds
    /// @param parentRoyalties The parent royalties
    /// @return newAncestors The new ancestors
    /// @return newAncestorsRoyalty The new ancestors royalty
    /// @return ancestorsCount The number of ancestors
    /// @return royaltyStack The royalty stack
    // solhint-disable-next-line code-complexity
    function _getExpectedOutputs(
        address[] memory parentIpIds,
        uint32[] memory parentRoyalties
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
        uint32[] memory newAncestorsRoyalty_ = new uint32[](MAX_ANCESTORS);
        address[] memory newAncestors_ = new address[](MAX_ANCESTORS);

        for (uint256 i = 0; i < parentIpIds.length; i++) {
            if (i == 0) {
                newAncestors_[ancestorsCount] = parentIpIds[i];
                newAncestorsRoyalty_[ancestorsCount] += parentRoyalties[i];
                royaltyStack += parentRoyalties[i];
                ancestorsCount++;
            } else if (i == 1) {
                (uint256 index, bool isIn) = ArrayUtils.indexOf(newAncestors_, parentIpIds[i]);
                if (!isIn) {
                    newAncestors_[ancestorsCount] = parentIpIds[i];
                    newAncestorsRoyalty_[ancestorsCount] += parentRoyalties[i];
                    royaltyStack += parentRoyalties[i];
                    ancestorsCount++;
                } else {
                    newAncestorsRoyalty_[index] += parentRoyalties[i];
                    royaltyStack += parentRoyalties[i];
                }
            }

            address[] memory parentAncestors = royaltyData[parentIpIds[i]].ancestorsAddresses;
            uint32[] memory parentAncestorsRoyalties = royaltyData[parentIpIds[i]].ancestorsRoyalties;

            for (uint256 j = 0; j < parentAncestors.length; j++) {
                if (i == 0) {
                    newAncestors_[ancestorsCount] = parentAncestors[j];
                    newAncestorsRoyalty_[ancestorsCount] += parentAncestorsRoyalties[j];
                    royaltyStack += parentAncestorsRoyalties[j];
                    ancestorsCount++;
                } else if (i == 1) {
                    (uint256 index, bool isIn) = ArrayUtils.indexOf(newAncestors_, parentAncestors[j]);
                    if (!isIn) {
                        newAncestors_[ancestorsCount] = parentAncestors[j];
                        newAncestorsRoyalty_[ancestorsCount] += parentAncestorsRoyalties[j];
                        royaltyStack += parentAncestorsRoyalties[j];
                        ancestorsCount++;
                    } else {
                        newAncestorsRoyalty_[index] += parentAncestorsRoyalties[j];
                        royaltyStack += parentAncestorsRoyalties[j];
                    }
                }
            }
        }

        // remove empty elements from each array
        newAncestors = new address[](ancestorsCount);
        newAncestorsRoyalty = new uint32[](ancestorsCount);
        for (uint256 k = 0; k < ancestorsCount; k++) {
            newAncestors[k] = newAncestors_[k];
            newAncestorsRoyalty[k] = newAncestorsRoyalty_[k];
        }
    }

    /// @dev Deploys a liquid split clone contract
    /// @param ipId The ipId
    /// @param ancestorsVault The ancestors vault address
    /// @param royaltyStack The number of rnfts that the ipId has to give to its parents and/or grandparents
    /// @return The address of the deployed liquid split clone contract
    function _deploySplitClone(address ipId, address ancestorsVault, uint32 royaltyStack) internal returns (address) {
        address[] memory accounts = new address[](2);
        accounts[0] = ipId;
        accounts[1] = ancestorsVault;

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

    /// @notice Returns the royalty data for a given IP asset
    /// @param ipId The ipId to get the royalty data for
    /// @return isUnlinkableToParents Indicates if the ipId is unlinkable to new parents
    /// @return splitClone The address of the liquid split clone contract for a given ipId
    /// @return ancestorsVault The address of the ancestors vault contract for a given ipId
    /// @return royaltyStack The royalty stack of a given ipId is the sum of the royalties to be paid to each ancestors
    /// @return ancestorsAddresses The ancestors addresses array
    /// @return ancestorsRoyalties The ancestors royalties array
    function getRoyaltyData(
        address ipId
    ) external view returns (bool, address, address, uint32, address[] memory, uint32[] memory) {
        LAPRoyaltyData memory data = royaltyData[ipId];
        return (
            data.isUnlinkableToParents,
            data.splitClone,
            data.ancestorsVault,
            data.royaltyStack,
            data.ancestorsAddresses,
            data.ancestorsRoyalties
        );
    }
}
