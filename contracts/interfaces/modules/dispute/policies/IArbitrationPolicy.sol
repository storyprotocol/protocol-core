// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

/// @title ArbitrationPolicy interface
interface IArbitrationPolicy {
    /// @notice Executes custom logic on raise dispute
    /// @param caller Address of the caller    
    function onRaiseDispute(address caller, bytes calldata data) external;

    /// @notice Executes custom logic on dispute judgement
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    function onDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external;

    /// @notice Executes custom logic on dispute cancel
    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external;
}
