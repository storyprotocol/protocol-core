// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IArbitrationPolicy} from "../../../interfaces/modules/dispute-module/policies/IArbitrationPolicy.sol";
import {IDisputeModule} from "../../../interfaces/modules/dispute-module/IDisputeModule.sol";

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Errors} from "../../lib/Errors.sol";

/// @title Story Protocol Dispute Module
/// @notice The Story Protocol dispute module acts as an enforcement layer for
///         that allows to raise disputes and resolve them through arbitration.
contract DisputeModule is IDisputeModule, ReentrancyGuard {
    /// @notice Dispute struct
    struct Dispute {
        address ipId; // The ipId
        address disputeInitiator; // The address of the dispute initiator
        address arbitrationPolicy; // The address of the arbitration policy
        bytes32 hashToDisputeSummary; // The hash of the dispute summary
        bytes32 tag; // The target tag of the dispute // TODO: move to tagging module?
    }

    /// @notice Dispute id
    uint256 public disputeId;

    /// @notice Contains the dispute struct info for a given dispute id
    mapping(uint256 disputeId => Dispute dispute) public disputes;

    /// @notice Indicates if a dispute tag is whitelisted
    mapping(bytes32 tag => bool allowed) public isWhitelistedDisputeTag;

    /// @notice Indicates if an arbitration policy is whitelisted
    mapping(address arbitrationPolicy => bool allowed) public isWhitelistedArbitrationPolicy;

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    mapping(address arbitrationPolicy => mapping(address arbitrationRelayer => bool allowed)) public
        isWhitelistedArbitrationRelayer;

    /// @notice Restricts the calls to the governance address
    modifier onlyGovernance() {
        // TODO: where is governance address defined?
        _;
    }

    /// @notice Whitelists a dispute tag
    /// @param _tag The dispute tag
    /// @param _allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTags(bytes32 _tag, bool _allowed) external onlyGovernance {
        if (_tag == bytes32(0)) revert Errors.DisputeModule__ZeroDisputeTag();

        isWhitelistedDisputeTag[_tag] = _allowed;

        // TODO: emit event
    }

    /// @notice Whitelists an arbitration policy
    /// @param _arbitrationPolicy The address of the arbitration policy
    /// @param _allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address _arbitrationPolicy, bool _allowed) external onlyGovernance {
        if (_arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();

        isWhitelistedArbitrationPolicy[_arbitrationPolicy] = _allowed;

        // TODO: emit event
    }

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param _arbitrationPolicy The address of the arbitration policy
    /// @param _arbPolicyRelayer The address of the arbitration relayer
    /// @param _allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(address _arbitrationPolicy, address _arbPolicyRelayer, bool _allowed)
        external
        onlyGovernance
    {
        if (_arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();
        if (_arbPolicyRelayer == address(0)) revert Errors.DisputeModule__ZeroArbitrationRelayer();

        isWhitelistedArbitrationRelayer[_arbitrationPolicy][_arbPolicyRelayer] = _allowed;

        // TODO: emit event
    }

    /// @notice Raises a dispute
    /// @param _ipId The ipId
    /// @param _arbitrationPolicy The address of the arbitration policy
    /// @param _hashToDisputeSummary The hash of the dispute summary
    /// @param _targetTag The target tag of the dispute
    /// @param _data The data to initialize the policy
    /// @return disputeId The dispute id
    function raiseDispute(
        address _ipId,
        address _arbitrationPolicy,
        bytes32 _hashToDisputeSummary,
        bytes32 _targetTag,
        bytes calldata _data
    ) external nonReentrant returns (uint256) {
        // TODO: make call to ensure ipId exists/has been registered
        if (!isWhitelistedArbitrationPolicy[_arbitrationPolicy]) {
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();
        }
        if (_hashToDisputeSummary == bytes32(0)) revert Errors.DisputeModule__ZeroHashToDisputeSummary();
        if (!isWhitelistedDisputeTag[_targetTag]) revert Errors.DisputeModule__NotWhitelistedDisputeTag();

        disputeId++;

        disputes[disputeId] = Dispute({
            ipId: _ipId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: _arbitrationPolicy,
            hashToDisputeSummary: _hashToDisputeSummary,
            tag: _targetTag
        });

        // TODO: set tag to "in-dispute" state

        IArbitrationPolicy(_arbitrationPolicy).onRaiseDispute(msg.sender, _data);

        // TODO: emit event

        return disputeId;
    }

    /// @notice Sets the dispute judgement
    /// @param _disputeId The dispute id
    /// @param _decision The decision of the dispute
    /// @param _data The data to set the dispute judgement
    function setDisputeJudgement(uint256 _disputeId, bool _decision, bytes calldata _data) external nonReentrant {
        address _arbitrationPolicy = disputes[_disputeId].arbitrationPolicy;

        // TODO: if dispute tag is not in "in-dispute" state then the function should revert - the same disputeId cannot be set twice + cancelled cannot be set
        if (!isWhitelistedArbitrationRelayer[_arbitrationPolicy][msg.sender]) {
            revert Errors.DisputeModule__NotWhitelistedArbitrationRelayer();
        }

        if (_decision) {
            // TODO: set tag to the target dispute tag state
        } else {
            // TODO: remove tag/set dispute tag to null state
        }

        IArbitrationPolicy(_arbitrationPolicy).onDisputeJudgement(_disputeId, _decision, _data);

        // TODO: emit event
    }

    /// @notice Cancels an ongoing dispute
    /// @param _disputeId The dispute id
    /// @param _data The data to cancel the dispute
    function cancelDispute(uint256 _disputeId, bytes calldata _data) external nonReentrant {
        if (msg.sender != disputes[_disputeId].disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();
        // TODO: if tag is not "in-dispute" then revert

        IArbitrationPolicy(disputes[_disputeId].arbitrationPolicy).onDisputeCancel(msg.sender, _disputeId, _data);

        // TODO: remove tag/set dispute tag to null state

        // TODO: emit event
    }

    /// @notice Resolves a dispute after it has been judged
    /// @param _disputeId The dispute id
    function resolveDispute(uint256 _disputeId) external {
        if (msg.sender != disputes[_disputeId].disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();
        // TODO: if tag is in "in-dispute" or already "null" then revert

        // TODO: remove tag/set dispute tag to null state

        // TODO: emit event
    }
}
