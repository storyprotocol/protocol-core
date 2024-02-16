// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { Governable } from "../../governance/Governable.sol";
import { IRoyaltyModule } from "../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { Errors } from "../../lib/Errors.sol";
import { ROYALTY_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";

/// @title Story Protocol Royalty Module
/// @notice The Story Protocol royalty module allows to set royalty policies an IP asset and pay royalties as a
///         derivative IP.
contract RoyaltyModule is IRoyaltyModule, Governable, ReentrancyGuard, BaseModule {
    using ERC165Checker for address;

    string public constant override name = ROYALTY_MODULE_KEY;

    /// @notice Returns the licensing module address
    address public LICENSING_MODULE;

    /// @notice Indicates if a royalty policy is whitelisted
    mapping(address royaltyPolicy => bool isWhitelisted) public isWhitelistedRoyaltyPolicy;

    /// @notice Indicates if a royalty token is whitelisted
    mapping(address token => bool) public isWhitelistedRoyaltyToken;

    /// @notice Indicates the royalty policy for a given IP asset
    mapping(address ipId => address royaltyPolicy) public royaltyPolicies;

    /// @notice Indicates if a royalty policy is immutable
    mapping(address ipId => bool isImmutable) public isRoyaltyPolicyImmutable;

    constructor(address _governance) Governable(_governance) {}

    /// @notice Modifier to enforce that the caller is the licensing module
    modifier onlyLicensingModule() {
        if (msg.sender != LICENSING_MODULE) revert Errors.RoyaltyModule__NotAllowedCaller();
        _;
    }

    /// @notice Sets the license registry
    /// @dev Enforced to be only callable by the protocol admin
    /// @param licensingModule The address of the license registry
    function setLicensingModule(address licensingModule) external onlyProtocolAdmin {
        if (licensingModule == address(0)) revert Errors.RoyaltyModule__ZeroLicensingModule();
        LICENSING_MODULE = licensingModule;
    }

    /// @notice Whitelist a royalty policy
    /// @dev Enforced to be only callable by the protocol admin
    /// @param royaltyPolicy The address of the royalty policy
    /// @param allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address royaltyPolicy, bool allowed) external onlyProtocolAdmin {
        if (royaltyPolicy == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyPolicy();

        isWhitelistedRoyaltyPolicy[royaltyPolicy] = allowed;

        emit RoyaltyPolicyWhitelistUpdated(royaltyPolicy, allowed);
    }

    /// @notice Whitelist a royalty token
    /// @dev Enforced to be only callable by the protocol admin
    /// @param token The token address
    /// @param allowed Indicates if the token is whitelisted or not
    function whitelistRoyaltyToken(address token, bool allowed) external onlyProtocolAdmin {
        if (token == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyToken();

        isWhitelistedRoyaltyToken[token] = allowed;

        emit RoyaltyTokenWhitelistUpdated(token, allowed);
    }

    // TODO: Ensure that the ipId that is passed in from license cannot be manipulated
    //       - given ipId addresses are deterministic
    /// @notice Sets the royalty policy for a given IP asset
    /// @dev Enforced to be only callable by the licensing module
    /// @param ipId The ID of IP asset
    /// @param royaltyPolicy The address of the royalty policy
    /// @param parentIpIds List of parent IP asset IDs
    /// @param data The data to initialize the policy
    function setRoyaltyPolicy(
        address ipId,
        address royaltyPolicy,
        address[] calldata parentIpIds,
        bytes calldata data
    ) external nonReentrant onlyLicensingModule {
        if (isRoyaltyPolicyImmutable[ipId]) revert Errors.RoyaltyModule__AlreadySetRoyaltyPolicy();
        if (!isWhitelistedRoyaltyPolicy[royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        if (parentIpIds.length > 0) isRoyaltyPolicyImmutable[ipId] = true;

        // the loop below is limited to 100 iterations
        for (uint32 i = 0; i < parentIpIds.length; i++) {
            if (royaltyPolicies[parentIpIds[i]] != royaltyPolicy)
                revert Errors.RoyaltyModule__IncompatibleRoyaltyPolicy();
            isRoyaltyPolicyImmutable[parentIpIds[i]] = true;
        }

        royaltyPolicies[ipId] = royaltyPolicy;

        IRoyaltyPolicy(royaltyPolicy).initPolicy(ipId, parentIpIds, data);

        emit RoyaltyPolicySet(ipId, royaltyPolicy, data);
    }

    /// @notice Sets the royalty policy as immutable
    /// @dev Enforced to be only callable by the licensing module
    /// @param ipId The ID of IP asset
    function setRoyaltyPolicyImmutable(address ipId) external onlyLicensingModule {
        isRoyaltyPolicyImmutable[ipId] = true;
    }

    // TODO: deprecate in favor of more flexible royalty data getters
    /// @notice Returns the minRoyalty for a given IP asset
    /// @param ipId The ID of IP asset
    /// @return minRoyalty The minimum royalty percentage, 10 units = 1%
    function minRoyaltyFromDescendants(address ipId) external view returns (uint256) {
        address royaltyPolicy = royaltyPolicies[ipId];
        if (royaltyPolicy == address(0)) revert Errors.RoyaltyModule__NoRoyaltyPolicySet();

        return IRoyaltyPolicy(royaltyPolicy).minRoyaltyFromDescendants(ipId);
    }

    /// @notice Allows a sender to to pay royalties on behalf of an given IP asset
    /// @param receiverIpId The ID of IP asset that receives the royalties
    /// @param payerIpId The ID of IP asset that pays the royalties
    /// @param token The token to use to pay the royalties
    /// @param amount The amount to pay
    function payRoyaltyOnBehalf(
        address receiverIpId,
        address payerIpId,
        address token,
        uint256 amount
    ) external nonReentrant {
        address royaltyPolicy = royaltyPolicies[receiverIpId];
        if (royaltyPolicy == address(0)) revert Errors.RoyaltyModule__NoRoyaltyPolicySet();
        if (!isWhitelistedRoyaltyToken[token]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyToken();
        if (!isWhitelistedRoyaltyPolicy[royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        IRoyaltyPolicy(royaltyPolicy).onRoyaltyPayment(msg.sender, receiverIpId, token, amount);

        emit RoyaltyPaid(receiverIpId, payerIpId, msg.sender, token, amount);
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IRoyaltyModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
