// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { DISPUTE_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../../modules/BaseModule.sol";
import { Governable } from "../../governance/Governable.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { IIPAssetRegistry } from "../../interfaces/registries/IIPAssetRegistry.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "../../interfaces/modules/dispute/policies/IArbitrationPolicy.sol";
import { Errors } from "../../lib/Errors.sol";
import { ShortStringOps } from "../../utils/ShortStringOps.sol";

/// @title Story Protocol Dispute Module
/// @notice The Story Protocol dispute module acts as an enforcement layer for
///         that allows to raise disputes and resolve them through arbitration.
contract DisputeModule is IDisputeModule, BaseModule, Governable, ReentrancyGuard, AccessControlled {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    /// @notice tag to represent the dispute is in dispute state waiting for judgement
    bytes32 public constant IN_DISPUTE = bytes32("IN_DISPUTE");

    IIPAssetRegistry public IP_ASSET_REGISTRY;

    /// @notice Dispute struct
    struct Dispute {
        address targetIpId; // The ipId that is the target of the dispute
        address disputeInitiator; // The address of the dispute initiator
        address arbitrationPolicy; // The address of the arbitration policy
        bytes32 linkToDisputeEvidence; // The link of the dispute evidence
        bytes32 targetTag; // The target tag of the dispute
        bytes32 currentTag; // The current tag of the dispute
    }

    /// @notice Dispute id
    uint256 public disputeId;

    /// @notice The address of the base arbitration policy
    address public baseArbitrationPolicy;

    /// @notice Contains the dispute information for a given dispute id
    mapping(uint256 disputeId => Dispute dispute) public disputes;

    /// @notice Indicates if a dispute tag is whitelisted
    mapping(bytes32 tag => bool allowed) public isWhitelistedDisputeTag;

    /// @notice Indicates if an arbitration policy is whitelisted
    mapping(address arbitrationPolicy => bool allowed) public isWhitelistedArbitrationPolicy;

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    mapping(address arbitrationPolicy => mapping(address arbitrationRelayer => bool allowed))
        public isWhitelistedArbitrationRelayer;

    /// @notice Arbitration policy for a given ipId
    mapping(address ipId => address arbitrationPolicy) public arbitrationPolicies;

    mapping(address ipId => EnumerableSet.Bytes32Set) private _taggedIpIds;

    /// @notice Initializes the registration module contract
    /// @param _controller The access controller used for IP authorization
    /// @param _assetRegistry The address of the IP asset registry
    /// @param _governance The address of the governance contract
    constructor(
        address _controller,
        address _assetRegistry,
        address _governance
    ) Governable(_governance) AccessControlled(_controller, _assetRegistry) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(_assetRegistry);
    }

    /// @notice Whitelists a dispute tag
    /// @param _tag The dispute tag
    /// @param _allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 _tag, bool _allowed) external onlyProtocolAdmin {
        if (_tag == bytes32(0)) revert Errors.DisputeModule__ZeroDisputeTag();

        isWhitelistedDisputeTag[_tag] = _allowed;

        emit TagWhitelistUpdated(_tag, _allowed);
    }

    /// @notice Whitelists an arbitration policy
    /// @param _arbitrationPolicy The address of the arbitration policy
    /// @param _allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address _arbitrationPolicy, bool _allowed) external onlyProtocolAdmin {
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
    ) external onlyProtocolAdmin {
        if (_arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();
        if (_arbPolicyRelayer == address(0)) revert Errors.DisputeModule__ZeroArbitrationRelayer();

        isWhitelistedArbitrationRelayer[_arbitrationPolicy][_arbPolicyRelayer] = _allowed;

        emit ArbitrationRelayerWhitelistUpdated(_arbitrationPolicy, _arbPolicyRelayer, _allowed);
    }

    /// @notice Sets the base arbitration policy
    /// @param _arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address _arbitrationPolicy) external onlyProtocolAdmin {
        if (!isWhitelistedArbitrationPolicy[_arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        baseArbitrationPolicy = _arbitrationPolicy;

        emit DefaultArbitrationPolicyUpdated(_arbitrationPolicy);
    }

    /// @notice Sets the arbitration policy for an ipId
    /// @param _ipId The ipId
    /// @param _arbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(address _ipId, address _arbitrationPolicy) external verifyPermission(_ipId) {
        if (!isWhitelistedArbitrationPolicy[_arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        arbitrationPolicies[_ipId] = _arbitrationPolicy;

        emit ArbitrationPolicySet(_ipId, _arbitrationPolicy);
    }

    /// @notice Raises a dispute
    /// @param _targetIpId The ipId that is the target of the dispute
    /// @param _linkToDisputeEvidence The link of the dispute evidence
    /// @param _targetTag The target tag of the dispute
    /// @param _data The data to initialize the policy
    /// @return disputeId The dispute id
    function raiseDispute(
        address _targetIpId,
        string memory _linkToDisputeEvidence,
        bytes32 _targetTag,
        bytes calldata _data
    ) external nonReentrant returns (uint256) {
        if (!IP_ASSET_REGISTRY.isRegistered(_targetIpId)) revert Errors.DisputeModule__NotRegisteredIpId();
        if (!isWhitelistedDisputeTag[_targetTag]) revert Errors.DisputeModule__NotWhitelistedDisputeTag();

        bytes32 linkToDisputeEvidence = ShortStringOps.stringToBytes32(_linkToDisputeEvidence);
        if (linkToDisputeEvidence == bytes32(0)) revert Errors.DisputeModule__ZeroLinkToDisputeEvidence();

        address arbitrationPolicy = arbitrationPolicies[_targetIpId];
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = baseArbitrationPolicy;

        uint256 disputeId_ = ++disputeId;

        disputes[disputeId_] = Dispute({
            targetIpId: _targetIpId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: arbitrationPolicy,
            linkToDisputeEvidence: linkToDisputeEvidence,
            targetTag: _targetTag,
            currentTag: IN_DISPUTE
        });

        IArbitrationPolicy(arbitrationPolicy).onRaiseDispute(msg.sender, _data);

        emit DisputeRaised(
            disputeId_,
            _targetIpId,
            msg.sender,
            arbitrationPolicy,
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
            // We ignore the result of add(), we don't care if the tag is already there
            _taggedIpIds[dispute.targetIpId].add(dispute.targetTag);
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

        // Ignore the result of remove(), resolveDispute can only be called once when there's a dispute tag.
        // Once resolveDispute is called, the tag will be removed and calling this fn again will throw an error.
        _taggedIpIds[dispute.targetIpId].remove(dispute.currentTag);
        disputes[_disputeId].currentTag = bytes32(0);

        emit DisputeResolved(_disputeId);
    }

    /// @notice returns true if the ipId is tagged with the tag (meaning the dispute went through)
    /// @param _ipId The ipId
    /// @param _tag The tag
    function isIpTaggedWith(address _ipId, bytes32 _tag) external view returns (bool) {
        return _taggedIpIds[_ipId].contains(_tag);
    }

    /// @notice returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param _ipId The ipId
    function isIpTagged(address _ipId) external view returns (bool) {
        return _taggedIpIds[_ipId].length() > 0;
    }

    /// @notice returns the tags for a given ipId (note: this method could be expensive, use in frontends only)
    /// @param _ipId The ipId
    function ipTags(address _ipId) external view returns (bytes32[] memory) {
        return _taggedIpIds[_ipId].values();
    }

    /// @notice returns the total tags for a given ipId
    /// @param _ipId The ipId
    function totalTagsForIp(address _ipId) external view returns (uint256) {
        return _taggedIpIds[_ipId].length();
    }

    /// @notice returns the tag at a given index for a given ipId. No guarantees on ordering
    /// @param _ipId The ipId
    function tagForIpAt(address _ipId, uint256 _index) external view returns (bytes32) {
        return _taggedIpIds[_ipId].at(_index);
    }

    /// @notice Gets the protocol-wide module identifier for this module
    /// @return The dispute module key
    function name() public pure override returns (string memory) {
        return DISPUTE_MODULE_KEY;
    }
}
