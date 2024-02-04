// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

/// @title 
/// @notice Contracts implementing this interface can be called by PolicyFrameworkManager to check
/// if an address is allowed to be a commercializer for a given license (meaning the candidate adddress
/// can commercially exploit the work, but it has to pass a check like token gating, whitelist...).
interface ICommercializerChecker {
    /// @notice Check if a candidate address is allowed to commercially exploit a work
    /// @param candidate The address of the candidate commercializer
    /// @param data The data to be used for the check
    /// @return Whether the candidate is allowed to commercially exploit the work
    function isAllowedCommercializer(address candidate, bytes memory data) external view returns (bool);

    /// @notice Return a description of the commercializer checker for LNFT metadata
    function description(bytes memory data) external view returns (string memory);
}