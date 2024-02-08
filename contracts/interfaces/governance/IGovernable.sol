// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title IGovernable
/// @notice This is the interface for the Lens Protocol main governance functions.
interface IGovernable {
    /// @notice Emitted when the governance is updated
    /// @param newGovernance The address of the new governance
    event GovernanceUpdated(address indexed newGovernance);
    /// @notice Sets the governance address
    /// @param newGovernance The address of the new governance
    function setGovernance(address newGovernance) external;
    /// @notice Returns the current governance address
    /// @return The address of the current governance
    function getGovernance() external view returns (address);
}
