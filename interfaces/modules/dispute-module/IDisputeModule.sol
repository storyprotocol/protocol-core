// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title Dispute Module Interface
interface IDisputeModule {
    /// @notice Whitelists a dispute tag
    /// @param tag The dispute tag
    /// @param allowed Indicates if the dispute tag is whitelisted or not
    function whitelistDisputeTags(bytes32 tag, bool allowed) external;

    /// @notice Whitelists an arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param allowed Indicates if the arbitration policy is whitelisted or not
    function whitelistArbitrationPolicy(address arbitrationPolicy, bool allowed) external;

    /// @notice Whitelists an arbitration relayer for a given arbitration policy
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param arbPolicyRelayer The address of the arbitration relayer
    /// @param allowed Indicates if the arbitration relayer is whitelisted or not
    function whitelistArbitrationRelayer(address arbitrationPolicy, address arbPolicyRelayer, bool allowed) external;
    
    /// @notice Raises a dispute
    /// @param ipId The ipId
    /// @param arbitrationPolicy The address of the arbitration policy
    /// @param linkToDisputeSummary The link of the dispute summary
    /// @param targetTag The target tag of the dispute
    /// @param data The data to initialize the policy
    /// @return disputeId The dispute id
    function raiseDispute(
        address ipId,
        address arbitrationPolicy,
        string memory linkToDisputeSummary,
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
    function disputes(uint256 disputeId) external view returns (
        address ipId,
        address disputeInitiator,
        address arbitrationPolicy,
        bytes32 linkToDisputeSummary,
        bytes32 tag
    );
}