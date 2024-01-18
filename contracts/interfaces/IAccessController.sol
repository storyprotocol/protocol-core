// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.21;

interface IAccessController {
    /// @notice Sets the policy for a specific function call
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient(modules) of the transaction
    /// @param func_ The function selector
    /// @param permission_ The permission level
    function setPolicy(address ipAccount_, address signer_, address to_, bytes4 func_, uint8 permission_) external;

    /// @notice Gets the policy for a specific function call
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient (modules) of the transaction
    /// @param func_ The function selector
    /// @return The current permission level for the function call
    function getPolicy(address ipAccount_, address signer_, address to_, bytes4 func_) external view returns (uint8);

    /// @notice Checks the policy for a specific function call
    /// @param ipAccount_ The account that owns the IP
    /// @param signer_ The account that signs the transaction
    /// @param to_ The recipient of the transaction
    /// @param func_ The function selector
    /// @return A boolean indicating whether the function call is allowed
    function checkPolicy(address ipAccount_, address signer_, address to_, bytes4 func_) external view returns (bool);
}
