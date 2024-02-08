// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title Arbitration Policy Interface
interface IArbitrationPolicy {
    /// @notice Event emitted when governance withdraws
    /// @param amount The amount withdrawn
    event GovernanceWithdrew(uint256 amount);

    /// @notice Executes custom logic on raise dispute
    /// @param caller Address of the caller
    /// @param data The data to raise the dispute
    function onRaiseDispute(address caller, bytes calldata data) external;

    /// @notice Executes custom logic on dispute judgement
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The data to set the dispute judgement
    function onDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external;

    /// @notice Executes custom logic on dispute cancel
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The data to cancel the dispute
    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external;

    /// @notice Allows governance address to withdraw
    function governanceWithdraw() external;
}
