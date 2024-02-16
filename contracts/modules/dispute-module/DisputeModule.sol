// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { DISPUTE_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../../modules/BaseModule.sol";
import { Governable } from "../../governance/Governable.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { IIPAssetRegistry } from "../../interfaces/registries/IIPAssetRegistry.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "../../interfaces/modules/dispute/policies/IArbitrationPolicy.sol";
import { Errors } from "../../lib/Errors.sol";
import { ShortStringOps } from "../../utils/ShortStringOps.sol";

/// @title Dispute Module
/// @notice The dispute module acts as an enforcement layer for IP assets that allows raising and resolving disputes 
/// through arbitration by judges.
contract DisputeModule is IDisputeModule, BaseModule, Governable, ReentrancyGuard, AccessControlled {
    string public constant override name = DISPUTE_MODULE_KEY;
    
    /// @notice Tag to represent the dispute is in dispute state waiting for judgement
    bytes32 public constant IN_DISPUTE = bytes32("IN_DISPUTE");
    
    /// @notice Tag to represent the dispute is in dispute state waiting for judgement
    IIPAssetRegistry public IP_ASSET_REGISTRY;

    /// @notice Dispute ID counter
    uint256 public disputeCounter;

    /// @notice The address of the base arbitration policy
    address public baseArbitrationPolicy;

    /// @notice Returns the dispute information for a given dispute id
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

    constructor(
        address _controller,
        address _assetRegistry,
        address _governance
    ) Governable(_governance) AccessControlled(_controller, _assetRegistry) {
        IP_ASSET_REGISTRY = IIPAssetRegistry(_assetRegistry);
    }

    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 tag, bool allowed) external onlyProtocolAdmin {
        if (tag == bytes32(0)) revert Errors.DisputeModule__ZeroDisputeTag();

        isWhitelistedDisputeTag[tag] = allowed;

        emit TagWhitelistUpdated(tag, allowed);
    }

    /// @notice Whitelists an arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address arbitrationPolicy, bool allowed) external onlyProtocolAdmin {
        if (arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();

        isWhitelistedArbitrationPolicy[arbitrationPolicy] = allowed;

        emit ArbitrationPolicyWhitelistUpdated(arbitrationPolicy, allowed);
    }

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(
        address arbitrationPolicy,
        address arbPolicyRelayer,
        bool allowed
    ) external onlyProtocolAdmin {
        if (arbitrationPolicy == address(0)) revert Errors.DisputeModule__ZeroArbitrationPolicy();
        if (arbPolicyRelayer == address(0)) revert Errors.DisputeModule__ZeroArbitrationRelayer();

        isWhitelistedArbitrationRelayer[arbitrationPolicy][arbPolicyRelayer] = allowed;

        emit ArbitrationRelayerWhitelistUpdated(arbitrationPolicy, arbPolicyRelayer, allowed);
    }

    /// @notice Sets the base arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address arbitrationPolicy) external onlyProtocolAdmin {
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        baseArbitrationPolicy = arbitrationPolicy;

        emit DefaultArbitrationPolicyUpdated(arbitrationPolicy);
    }

    /// @notice Sets the arbitration policy for an ipId
    /// @param ipId The ipId
    /// @param arbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(address ipId, address arbitrationPolicy) external verifyPermission(ipId) {
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy])
            revert Errors.DisputeModule__NotWhitelistedArbitrationPolicy();

        arbitrationPolicies[ipId] = arbitrationPolicy;

        emit ArbitrationPolicySet(ipId, arbitrationPolicy);
    }

    /// @notice Raises a dispute
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param linkToDisputeEvidence The link of the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to initialize the policy
    /// @return disputeId The id of the newly raised dispute
    function raiseDispute(
        address targetIpId,
        string memory linkToDisputeEvidence,
        bytes32 targetTag,
        bytes calldata data
    ) external nonReentrant returns (uint256) {
        if (!IP_ASSET_REGISTRY.isRegistered(targetIpId)) revert Errors.DisputeModule__NotRegisteredIpId();
        if (!isWhitelistedDisputeTag[targetTag]) revert Errors.DisputeModule__NotWhitelistedDisputeTag();

        bytes32 linkToDisputeEvidenceBytes = ShortStringOps.stringToBytes32(linkToDisputeEvidence);
        if (linkToDisputeEvidenceBytes == bytes32(0)) revert Errors.DisputeModule__ZeroLinkToDisputeEvidence();

        address arbitrationPolicy = arbitrationPolicies[targetIpId];
        if (!isWhitelistedArbitrationPolicy[arbitrationPolicy]) arbitrationPolicy = baseArbitrationPolicy;

        uint256 disputeId_ = ++disputeCounter;

        disputes[disputeId_] = Dispute({
            targetIpId: targetIpId,
            disputeInitiator: msg.sender,
            arbitrationPolicy: arbitrationPolicy,
            linkToDisputeEvidence: linkToDisputeEvidenceBytes,
            targetTag: targetTag,
            currentTag: IN_DISPUTE
        });

        IArbitrationPolicy(arbitrationPolicy).onRaiseDispute(msg.sender, data);

        emit DisputeRaised(
            disputeId_,
            targetIpId,
            msg.sender,
            arbitrationPolicy,
            linkToDisputeEvidenceBytes,
            targetTag,
            data
        );

        return disputeId_;
    }

    /// @notice Sets the dispute judgement
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function setDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external nonReentrant {
        Dispute memory dispute = disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (!isWhitelistedArbitrationRelayer[dispute.arbitrationPolicy][msg.sender]) {
            revert Errors.DisputeModule__NotWhitelistedArbitrationRelayer();
        }

        if (decision) {
            disputes[disputeId].currentTag = dispute.targetTag;
        } else {
            disputes[disputeId].currentTag = bytes32(0);
        }

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeJudgement(disputeId, decision, data);

        emit DisputeJudgementSet(disputeId, decision, data);
    }

    /// @notice Cancels an ongoing dispute
    /// @param disputeId The dispute id
    /// @param data The data to cancel the dispute
    function cancelDispute(uint256 disputeId, bytes calldata data) external nonReentrant {
        Dispute memory dispute = disputes[disputeId];

        if (dispute.currentTag != IN_DISPUTE) revert Errors.DisputeModule__NotInDisputeState();
        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();

        IArbitrationPolicy(dispute.arbitrationPolicy).onDisputeCancel(msg.sender, disputeId, data);

        disputes[disputeId].currentTag = bytes32(0);

        emit DisputeCancelled(disputeId, data);
    }

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute id
    function resolveDispute(uint256 disputeId) external {
        Dispute memory dispute = disputes[disputeId];

        if (dispute.currentTag == IN_DISPUTE) revert Errors.DisputeModule__NotAbleToResolve();
        if (msg.sender != dispute.disputeInitiator) revert Errors.DisputeModule__NotDisputeInitiator();

        disputes[disputeId].currentTag = bytes32(0);

        emit DisputeResolved(disputeId);
    }
}
