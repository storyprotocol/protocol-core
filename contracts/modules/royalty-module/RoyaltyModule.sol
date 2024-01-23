// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// contracts
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Story Protocol Royalty Module
/// @notice The Story Protocol royalty module allows to set royalty policies an ipId
///         and pay royalties as a derivative ip.
contract RoyaltyModule is IRoyaltyModule, ReentrancyGuard {
    /// @notice Indicates if a royalty policy is whitelisted
    mapping(address royaltyPolicy => bool allowed) public isWhitelistedRoyaltyPolicy;

    /// @notice Indicates the royalty policy for a given ipId
    mapping(address ipId => address royaltyPolicy) public royaltyPolicies;

    /// @notice Restricts the calls to the governance address
    modifier onlyGovernance() {
        // TODO: where is governance address defined?
        _;
    }

    /// @notice Restricts the calls to the license module
    modifier onlyLicenseModule() {
        // TODO: where is license module address defined?
        _;
    }

    /// @notice Restricts the calls to a IPAccount
    modifier onlyIPAccount() {
        // TODO: where to find if an address is a valid IPAccount or an approved operator?
        _;
    }

    /// @notice Whitelist a royalty policy
    /// @param _royaltyPolicy The address of the royalty policy
    /// @param _allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address _royaltyPolicy, bool _allowed) external onlyGovernance {
        if (_royaltyPolicy == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyPolicy();

        isWhitelistedRoyaltyPolicy[_royaltyPolicy] = _allowed;

        // TODO: emit event
    }

    /// @notice Sets the royalty policy for an ipId
    /// @param _ipId The ipId
    /// @param _royaltyPolicy The address of the royalty policy
    /// @param _data The data to initialize the policy
    function setRoyaltyPolicy(
        address _ipId,
        address _royaltyPolicy,
        bytes calldata _data
    ) external onlyLicenseModule nonReentrant {
        // TODO: make call to ensure ipId exists/has been registered
        if (!isWhitelistedRoyaltyPolicy[_royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();
        if (royaltyPolicies[_ipId] != address(0)) revert Errors.RoyaltyModule__AlreadySetRoyaltyPolicy();
        // TODO: check if royalty policy is compatible with parents royalty policy

        royaltyPolicies[_ipId] = _royaltyPolicy;

        IRoyaltyPolicy(_royaltyPolicy).initPolicy(_ipId, _data);

        // TODO: emit event
    }

    /// @notice Allows an IPAccount to pay royalties
    /// @param _ipId The ipId
    /// @param _token The token to pay the royalties in
    /// @param _amount The amount to pay
    function payRoyalty(address _ipId, address _token, uint256 _amount) external onlyIPAccount nonReentrant {
        IRoyaltyPolicy(royaltyPolicies[_ipId]).onRoyaltyPayment(msg.sender, _ipId, _token, _amount);

        // TODO: emit event
    }
}
