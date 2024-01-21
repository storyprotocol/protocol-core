// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

interface IAccessController {
    /// @notice Sets the permission for a specific function call
    /// @dev Each policy is represented as a mapping from an IP account address to a signer address to a recipient
    ///// address to a function selector to a permission level.
    ///// The permission level can be 0 (ABSTAIN), 1 (ALLOW), or 2 (DENY).
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient(modules) of the transaction
    /// @param func_ The function selector
    /// @param permission_ The permission level
    function setPermission(address ipAccount_, address signer_, address to_, bytes4 func_, uint8 permission_) external;

    /// @notice Gets the permission for a specific function call
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient (modules) of the transaction
    /// @param func_ The function selector
    /// @return The current permission level for the function call
    function getPermission(
        address ipAccount_,
        address signer_,
        address to_,
        bytes4 func_
    ) external view returns (uint8);

    /// @notice Checks the permission for a specific function call
    /// @dev This function checks the permission level for a specific function call.
    /// If a specific permission is set, it overrides the general (wildcard) permission.
    /// If the current level permission is ABSTAIN, the final permission is determined by the upper level.
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient of the transaction
    /// @param func_ The function selector
    /// @return A boolean indicating whether the function call is allowed
    function checkPermission(
        address ipAccount_,
        address signer_,
        address to_,
        bytes4 func_
    ) external view returns (bool);
}
