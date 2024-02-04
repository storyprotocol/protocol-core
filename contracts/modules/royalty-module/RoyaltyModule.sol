// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// contracts
import { Governable } from "contracts/governance/Governable.sol";
import { IRoyaltyModule } from "contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Story Protocol Royalty Module
/// @notice The Story Protocol royalty module allows to set royalty policies an ipId
///         and pay royalties as a derivative ip.
contract RoyaltyModule is IRoyaltyModule, Governable, ReentrancyGuard {
    /// @notice registration module address
    address public REGISTRATION_MODULE;

    /// @notice Indicates if a royalty policy is whitelisted
    mapping(address royaltyPolicy => bool allowed) public isWhitelistedRoyaltyPolicy;

    /// @notice Indicates if a royalty token is whitelisted
    mapping(address token => bool) public isWhitelistedRoyaltyToken;

    /// @notice Indicates the royalty policy for a given ipId
    mapping(address ipId => address royaltyPolicy) public royaltyPolicies;

    /// @notice Restricts the calls to the license module
    modifier onlyRegistrationModule() {
        // TODO: if (msg.sender != REGISTRATION_MODULE) revert Errors.RoyaltyModule__NotRegistrationModule();
        _;
    }

    /// @notice Constructor
    /// @param _governance The address of the governance contract
    constructor(address _governance) Governable(_governance) {}

    function initialize(address _registrationModule) external onlyProtocolAdmin {
        if (_registrationModule == address(0)) revert Errors.RoyaltyModule__ZeroLicensingModule();
        REGISTRATION_MODULE = _registrationModule;
    }

    /// @notice Whitelist a royalty policy
    /// @param _royaltyPolicy The address of the royalty policy
    /// @param _allowed Indicates if the royalty policy is whitelisted or not
    function whitelistRoyaltyPolicy(address _royaltyPolicy, bool _allowed) external onlyProtocolAdmin {
        if (_royaltyPolicy == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyPolicy();

        isWhitelistedRoyaltyPolicy[_royaltyPolicy] = _allowed;

        emit RoyaltyPolicyWhitelistUpdated(_royaltyPolicy, _allowed);
    }

    /// @notice Whitelist a royalty token
    /// @param _token The token address
    /// @param _allowed Indicates if the token is whitelisted or not
    function whitelistRoyaltyToken(address _token, bool _allowed) external onlyProtocolAdmin {
        if (_token == address(0)) revert Errors.RoyaltyModule__ZeroRoyaltyToken();

        isWhitelistedRoyaltyToken[_token] = _allowed;

        emit RoyaltyTokenWhitelistUpdated(_token, _allowed);
    }

    // TODO: Ensure this function is called on ipId registration: root and derivatives registrations
    // TODO: Ensure that the ipId that is passed in from license cannot be manipulated - given ipId addresses are deterministic
    /// @notice Sets the royalty policy for an ipId
    /// @param _ipId The ipId
    /// @param _royaltyPolicy The address of the royalty policy
    /// @param _parentIpIds The parent ipIds
    /// @param _data The data to initialize the policy
    function setRoyaltyPolicy(
        address _ipId, 
        address _royaltyPolicy,
        address[] calldata _parentIpIds,
        bytes calldata _data
    ) external onlyRegistrationModule nonReentrant {
        if (royaltyPolicies[_ipId] != address(0)) revert Errors.RoyaltyModule__AlreadySetRoyaltyPolicy();
        if (!isWhitelistedRoyaltyPolicy[_royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        for (uint32 i = 0; i < _parentIpIds.length; i++) {
            if (royaltyPolicies[_parentIpIds[i]] != _royaltyPolicy) revert Errors.RoyaltyModule__IncompatibleRoyaltyPolicy();
        }

        royaltyPolicies[_ipId] = _royaltyPolicy;

        IRoyaltyPolicy(_royaltyPolicy).initPolicy(_ipId, _parentIpIds, _data);

        emit RoyaltyPolicySet(_ipId, _royaltyPolicy, _data);
    }

    /// @notice Allows a sender to to pay royalties on behalf of an ipId
    /// @param _receiverIpId The ipId that receives the royalties
    /// @param _payerIpId The ipId that pays the royalties
    /// @param _token The token to use to pay the royalties
    /// @param _amount The amount to pay
    function payRoyaltyOnBehalf(address _receiverIpId, address _payerIpId, address _token, uint256 _amount) external nonReentrant {
        address royaltyPolicy = royaltyPolicies[_receiverIpId];
        if (royaltyPolicy == address(0)) revert Errors.RoyaltyModule__NoRoyaltyPolicySet();
        if (!isWhitelistedRoyaltyToken[_token]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyToken();
        if (!isWhitelistedRoyaltyPolicy[royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        IRoyaltyPolicy(royaltyPolicy).onRoyaltyPayment(msg.sender, _receiverIpId, _token, _amount);

        emit RoyaltyPaid(_receiverIpId, _payerIpId, msg.sender, _token, _amount);
    }
}