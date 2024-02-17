// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { BaseModule } from "../BaseModule.sol";
import { Governable } from "../../governance/Governable.sol";
import { IRoyaltyModule } from "../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "../../interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";
import { Errors } from "../../lib/Errors.sol";
import { ROYALTY_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";

/// @title Story Protocol Royalty Module
/// @notice The Story Protocol royalty module allows to set royalty policies an ipId
///         and pay royalties as a derivative ip.
contract RoyaltyModule is IRoyaltyModule, Governable, ReentrancyGuard, BaseModule {
    using ERC165Checker for address;

    string public constant override name = ROYALTY_MODULE_KEY;

    /// @notice Licensing module address
    address public LICENSING_MODULE;

    /// @notice Indicates if a royalty policy is whitelisted
    mapping(address royaltyPolicy => bool allowed) public isWhitelistedRoyaltyPolicy;

    /// @notice Indicates if a royalty token is whitelisted
    mapping(address token => bool) public isWhitelistedRoyaltyToken;

    /// @notice Indicates the royalty policy for a given ipId
    mapping(address ipId => address royaltyPolicy) public royaltyPolicies;

    /// @notice Constructor
    /// @param _governance The address of the governance contract
    constructor(address _governance) Governable(_governance) {}

    modifier onlyLicensingModule() {
        if (msg.sender != LICENSING_MODULE) revert Errors.RoyaltyModule__NotAllowedCaller();
        _;
    }

    /// @notice Sets the license registry
    /// @param _licensingModule The address of the license registry
    function setLicensingModule(address _licensingModule) external onlyProtocolAdmin {
        if (_licensingModule == address(0)) revert Errors.RoyaltyModule__ZeroLicensingModule();

        LICENSING_MODULE = _licensingModule;
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

    /// @notice Executes royalty related logic on license minting
    /// @param _ipId The ipId whose license is being minted (licensor)
    /// @param _royaltyPolicy The royalty policy address of the license being minted
    /// @param _licenseData The license data custom to each the royalty policy
    /// @param _externalData The external data custom to each the royalty policy
    function onLicenseMinting(
        address _ipId,
        address _royaltyPolicy,
        bytes calldata _licenseData,
        bytes calldata _externalData
    ) external nonReentrant onlyLicensingModule {
        if (!isWhitelistedRoyaltyPolicy[_royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        address royaltyPolicyIpId = royaltyPolicies[_ipId];

        // if the node is a root node, then royaltyPolicyIpId will be address(0) and any type of royalty type can be
        // selected to mint a license if the node is a derivative node, then the any minted licenses by the derivative
        // node should have the same royalty policy as the parent node a derivative node set its royalty policy
        // immutably in onLinkToParents() function below
        if (royaltyPolicyIpId != _royaltyPolicy && royaltyPolicyIpId != address(0))
            revert Errors.RoyaltyModule__CanOnlyMintSelectedPolicy();

        IRoyaltyPolicy(_royaltyPolicy).onLicenseMinting(_ipId, _licenseData, _externalData);
    }

    /// @notice Executes royalty related logic on linking to parents
    /// @param _ipId The children ipId that is being linked to parents
    /// @param _royaltyPolicy The common royalty policy address of all the licenses being burned
    /// @param _parentIpIds The parent ipIds that the children ipId is being linked to
    /// @param _licenseData The license data custom to each the royalty policy
    /// @param _externalData The external data custom to each the royalty policy
    function onLinkToParents(
        address _ipId,
        address _royaltyPolicy,
        address[] calldata _parentIpIds,
        bytes[] memory _licenseData,
        bytes calldata _externalData
    ) external nonReentrant onlyLicensingModule {
        if (!isWhitelistedRoyaltyPolicy[_royaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();
        if (_parentIpIds.length == 0) revert Errors.RoyaltyModule__NoParentsOnLinking();

        for (uint32 i = 0; i < _parentIpIds.length; i++) {
            address parentRoyaltyPolicy = royaltyPolicies[_parentIpIds[i]];
            // if the parent node has a royalty policy set, then the derivative node should have the same royalty
            // policy if the parent node does not have a royalty policy set, then the derivative node can set any type
            // of royalty policy as long as the children ip obtained and is burning all licenses with that royalty type
            // from each parent (was checked in licensing module before calling this function)
            if (parentRoyaltyPolicy != _royaltyPolicy && parentRoyaltyPolicy != address(0))
                revert Errors.RoyaltyModule__IncompatibleRoyaltyPolicy();
        }

        royaltyPolicies[_ipId] = _royaltyPolicy;

        IRoyaltyPolicy(_royaltyPolicy).onLinkToParents(_ipId, _parentIpIds, _licenseData, _externalData);
    }

    /// @notice Allows a sender to to pay royalties on behalf of an ipId
    /// @param _receiverIpId The ipId that receives the royalties
    /// @param _payerIpId The ipId that pays the royalties
    /// @param _token The token to use to pay the royalties
    /// @param _amount The amount to pay
    function payRoyaltyOnBehalf(
        address _receiverIpId,
        address _payerIpId,
        address _token,
        uint256 _amount
    ) external nonReentrant {
        if (!isWhitelistedRoyaltyToken[_token]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyToken();

        address payerRoyaltyPolicy = royaltyPolicies[_payerIpId];
        // if the payer does not have a royalty policy set, then the payer is not a derivative ip and does not pay
        // royalties the receiver ip can have a zero royalty policy since that could mean it is an ip a root
        if (payerRoyaltyPolicy == address(0)) revert Errors.RoyaltyModule__NoRoyaltyPolicySet();
        if (!isWhitelistedRoyaltyPolicy[payerRoyaltyPolicy]) revert Errors.RoyaltyModule__NotWhitelistedRoyaltyPolicy();

        IRoyaltyPolicy(payerRoyaltyPolicy).onRoyaltyPayment(msg.sender, _receiverIpId, _token, _amount);

        emit RoyaltyPaid(_receiverIpId, _payerIpId, msg.sender, _token, _amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IRoyaltyModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
