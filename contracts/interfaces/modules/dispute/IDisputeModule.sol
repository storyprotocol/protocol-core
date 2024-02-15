// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title Dispute Module Interface
interface IDisputeModule {
    /// @notice Event emitted when a dispute tag whitelist status is updated
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted
    event TagWhitelistUpdated(bytes32 tag, bool allowed);

    /// @notice Event emitted when an arbitration policy whitelist status is updated
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted
    event ArbitrationPolicyWhitelistUpdated(address arbitrationPolicy, bool allowed);

    /// @notice Event emitted when an arbitration relayer whitelist status is updated
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted
    event ArbitrationRelayerWhitelistUpdated(address arbitrationPolicy, address arbitrationRelayer, bool allowed);

    /// @notice Event emitted when the base arbitration policy is set
    /// @param arbitrationPolicy The address of the arbitration policy
    event DefaultArbitrationPolicyUpdated(address arbitrationPolicy);

    /// @notice Event emitted when an arbitration policy is set for an ipId
    /// @param ipId The ipId address
    /// @param arbitrationPolicy The address of the arbitration policy
    event ArbitrationPolicySet(address ipId, address arbitrationPolicy);

    /// @notice Event emitted when a dispute is raised
    /// @param disputeId The dispute id
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeInitiator The address of the dispute initiator
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param linkToDisputeEvidence The link of the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data Custom data adjusted to each policy
    event DisputeRaised(
        uint256 disputeId,
        address targetIpId,
        address disputeInitiator,
        address arbitrationPolicy,
        bytes32 linkToDisputeEvidence,
        bytes32 targetTag,
        bytes data
    );

    /// @notice Event emitted when a dispute judgement is set
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data Custom data adjusted to each policy
    event DisputeJudgementSet(uint256 disputeId, bool decision, bytes data);

    /// @notice Event emitted when a dispute is cancelled
    /// @param disputeId The dispute id
    /// @param data Custom data adjusted to each policy
    event DisputeCancelled(uint256 disputeId, bytes data);

    /// @notice Event emitted when a dispute is resolved
    /// @param disputeId The dispute id
    event DisputeResolved(uint256 disputeId);

    /// @notice Dispute id
    function disputeId() external view returns (uint256);

    /// @notice The address of the base arbitration policy
    function baseArbitrationPolicy() external view returns (address);

    /// @notice Indicates if a dispute tag is whitelisted
    /// @param tag The dispute tag
    function isWhitelistedDisputeTag(bytes32 tag) external view returns (bool allowed);

    /// @notice Indicates if an arbitration policy is whitelisted
    /// @param arbitrationPolicy The address of the arbitration policy
    function isWhitelistedArbitrationPolicy(address arbitrationPolicy) external view returns (bool allowed);

    /// @notice Indicates if an arbitration relayer is whitelisted for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbitrationRelayer The address of the arbitration relayer
    function isWhitelistedArbitrationRelayer(
        address arbitrationPolicy,
        address arbitrationRelayer
    ) external view returns (bool allowed);

    /// @notice Arbitration policy for a given ipId
    /// @param ipId The ipId
    function arbitrationPolicies(address ipId) external view returns (address policy);

    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTag(bytes32 tag, bool allowed) external;

    /// @notice Whitelists an arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address arbitrationPolicy, bool allowed) external;

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(address arbitrationPolicy, address arbPolicyRelayer, bool allowed) external;

    /// @notice Sets the base arbitration policy
    /// @param _arbitrationPolicy The address of the arbitration policy
    function setBaseArbitrationPolicy(address _arbitrationPolicy) external;

    /// @notice Sets the arbitration policy for an ipId
    /// @param _ipId The ipId
    /// @param _arbitrationPolicy The address of the arbitration policy
    function setArbitrationPolicy(address _ipId, address _arbitrationPolicy) external;

    /// @notice Raises a dispute
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param linkToDisputeEvidence The link of the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param data The data to initialize the policy
    /// @return disputeId The dispute id
    function raiseDispute(
        address targetIpId,
        string memory linkToDisputeEvidence,
        bytes32 targetTag,
        bytes calldata data
    ) external returns (uint256 disputeId);

    /// @notice Sets the dispute judgement
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function setDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external;

    /// @notice Cancels an ongoing dispute
    /// @param disputeId The dispute id
    /// @param data The data to cancel the dispute
    function cancelDispute(uint256 disputeId, bytes calldata data) external;

    /// @notice Resolves a dispute after it has been judged
    /// @param disputeId The dispute id
    function resolveDispute(uint256 disputeId) external;

    /// @notice Gets the dispute struct characteristics
    /// @param disputeId The dispute id
    function disputes(
        uint256 disputeId
    )
        external
        view
        returns (
            address targetIpId, // The ipId that is the target of the dispute
            address disputeInitiator, // The address of the dispute initiator
            address arbitrationPolicy, // The address of the arbitration policy
            bytes32 linkToDisputeEvidence, // The link of the dispute summary
            bytes32 targetTag, // The target tag of the dispute
            bytes32 currentTag // The current tag of the dispute
        );

    /// @notice returns true if the ipId is tagged with the tag (meaning the dispute went through)
    /// @param _ipId The ipId
    /// @param _tag The tag
    function isIpTaggedWith(address _ipId, bytes32 _tag) external view returns (bool);
    
    /// @notice returns true if the ipId is tagged with any tag (meaning at least one dispute went through)
    /// @param _ipId The ipId
    function isIpTagged(address _ipId) external view returns (bool);
    
    /// @notice returns the tags for a given ipId (note: this method could be expensive, use in frontends only)
    /// @param _ipId The ipId
    function ipTags(address _ipId) external view returns (bytes32[] memory);
    
    /// @notice returns the total tags for a given ipId
    /// @param _ipId The ipId
    function totalTagsForIp(address _ipId) external view returns (uint256);
    
    /// @notice returns the tag at a given index for a given ipId. No guarantees on ordering
    /// @param _ipId The ipId
    function tagForIpAt(address _ipId, uint256 _index) external view returns (bytes32);
}
