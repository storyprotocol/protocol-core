// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
// contracts
import { IDisputeModule } from "contracts/interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "contracts/interfaces/modules/dispute/policies/IArbitrationPolicy.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

/// @title Story Protocol Dispute Module
/// @notice The Story Protocol dispute module acts as an enforcement layer for
///         that allows to raise disputes and resolve them through arbitration.
contract DisputeModule is IDisputeModule, ReentrancyGuard {
    /// @notice Dispute struct
    struct Dispute {
        address targetIpId; // The ipId that is the target of the dispute
        address disputeInitiator; // The address of the dispute initiator
        address arbitrationPolicy; // The address of the arbitration policy
        bytes32 linkToDisputeEvidence; // The link of the dispute summary
        bytes32 targetTag; // The target tag of the dispute
        bytes32 currentTag; // The current tag of the dispute
    }

    // TODO: confirm if contracts will be upgradeable or not
    bytes32 public constant IN_DISPUTE = bytes32("IN_DISPUTE");

    /// @notice Dispute id
    uint256 public disputeId;

    /// @notice Contains the dispute struct info for a given dispute id
    mapping(uint256 disputeId => Dispute dispute) public disputes;

    /// @notice Indicates if a dispute tag is whitelisted
    mapping(bytes32 tag => bool allowed) public isWhitelistedDisputeTag;

    /// @notice Indicates if an arbitration policy is whitelisted
    mapping(address arbitrationPolicy => bool allowed) public isWhitelistedArbitrationPolicy;

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    mapping(address arbitrationPolicy => mapping(address arbitrationRelayer => bool allowed))
        public isWhitelistedArbitrationRelayer;

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

        emit TagWhitelistUpdated(_tag, _allowed);
    }

    /// @notice Whitelists an arbitration policy
    /// @param _arbitrationPolicy The address of the arbitration policy
    /// @param _allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address _arbitrationPolicy, bool _allowed) external onlyGovernance {
        if (_arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();

        isWhitelistedArbitrationPolicy[_arbitrationPolicy] = _allowed;

        emit ArbitrationPolicyWhitelistUpdated(_arbitrationPolicy, _allowed);
    }

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param _arbitrationPolicy The address of the arbitration policy
    /// @param _arbPolicyRelayer The address of the arbitration relayer
    /// @param _allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(
        address _arbitrationPolicy,
        address _arbPolicyRelayer,
        bool _allowed
    ) external onlyGovernance {
        if (_arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();
        if (_arbPolicyRelayer == address(0)) revert Errors.DisputeModule__ZeroArbitrationRelayer();

        isWhitelistedArbitrationRelayer[_arbitrationPolicy][_arbPolicyRelayer] = _allowed;

        emit ArbitrationRelayerWhitelistUpdated(_arbitrationPolicy, _arbPolicyRelayer, _allowed);
    }

    /// @notice Raises a dispute
    /// @param _targetIpId The ipId that is the target of the dispute
    /// @param _arbitrationPolicy The address of the arbitration policy
    /// @param _linkToDisputeEvidence The link of the dispute evidence
    /// @param _targetTag The target tag of the dispute
    /// @param _data The data to initialize the policy
    /// @return disputeId The dispute id
    function raiseDispute(
        address _targetIpId,
        address _arbitrationPolicy,
        string memory _linkToDisputeEvidence,
        bytes32 _targetTag,
        bytes calldata _data
    ) external nonReentrant returns (uint256) {
        // TODO: ensure the _targetIpId address is an existing/valid IPAccount
        if (!isWhitelistedArbitrationPolicy[_arbitrationPolicy]) {
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();
        }
        if (!isWhitelistedDisputeTag[_targetTag]) revert Errors.DisputeModule__NotWhitelistedDisputeTag();

        bytes32 linkToDisputeEvidence = ShortStringOps.stringToBytes32(_linkToDisputeEvidence);
        if (linkToDisputeEvidence == bytes32(0)) revert Errors.DisputeModule__ZeroLinkToDisputeEvidence();

        uint256 disputeId_ = ++disputeId;

        disputes[disputeId_] = Dispute({
            targetIpId: _targetIpId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: _arbitrationPolicy,
            linkToDisputeEvidence: linkToDisputeEvidence,
            targetTag: _targetTag,
            currentTag: IN_DISPUTE
        });

        IArbitrationPolicy(_arbitrationPolicy).onRaiseDispute(msg.sender, _data);

        emit DisputeRaised(
            disputeId_,
            _targetIpId,
            msg.sender,
            _arbitrationPolicy,
            linkToDisputeEvidence,
            _targetTag,
            _data
        );

        return disputeId_;
    }

    /// @notice Sets the dispute judgement
    /// @param _disputeId The dispute id
    /// @param _decision The decision of the dispute
    /// @param _data The data to set the dispute judgement
    function setDisputeJudgement(uint256 _disputeId, bool _decision, bytes calldata _data) external nonReentrant {
        Dispute memory dispute = disputes[_disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (!isWhitelistedArbitrationRelayer[dispute.arbitrationPolicy][msg.sender]) {
            revert Errors.DisputeModule__NotWhitelistedArbitrationRelayer();
        }

        if (_decision) {
            disputes[_disputeId].currentTag = dispute.targetTag;
        } else {
            disputes[_disputeId].currentTag = bytes32(0);
        }

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeJudgement(_disputeId, _decision, _data);

        emit DisputeJudgementSet(_disputeId, _decision, _data);
    }

    /// @notice Cancels an ongoing dispute
    /// @param _disputeId The dispute id
    /// @param _data The data to cancel the dispute
    function cancelDispute(uint256 _disputeId, bytes calldata _data) external nonReentrant {
        Dispute memory dispute = disputes[_disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeCancel(msg.sender, _disputeId, _data);

        disputes[_disputeId].currentTag = bytes32(0);

        emit DisputeCancelled(_disputeId, _data);
    }

    /// @notice Resolves a dispute after it has been judged
    /// @param _disputeId The dispute id
    function resolveDispute(uint256 _disputeId) external {
        Dispute memory dispute = disputes[_disputeId];

        if (dispute.currentTag == IN_DISPUTE) revert Errors.DisputeModule__NotAbleToResolve();
        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();

        disputes[_disputeId].currentTag = bytes32(0);

        emit DisputeResolved(_disputeId);
    }
}
