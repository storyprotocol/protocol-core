// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC6551Account } from "erc6551/interfaces/IERC6551Account.sol";

/// @title IIPAccount
/// @dev IPAccount is a token-bound account that adopts the EIP-6551 standard.
/// These accounts are deployed at deterministic addresses through the official 6551 account registry.
/// As a deployed smart contract, IPAccount can store IP-related information,
/// like ownership of other NFTs such as license NFT or Royalty NFT.
/// IPAccount can interact with modules by making calls as a normal transaction sender.
/// This allows for seamless operations on the state and data of IP.
/// IPAccount is core identity for all actions.
interface IIPAccount is IERC6551Account, IERC721Receiver, IERC1155Receiver {
    /// @notice Emitted when a transaction is executed.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether sent.
    /// @param data The data sent along with the transaction.
    /// @param nonce The nonce of the transaction.
    event Executed(address indexed to, uint256 value, bytes data, uint256 nonce);

    /// @notice Emitted when a transaction is executed on behalf of the signer.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether sent.
    /// @param data The data sent along with the transaction.
    /// @param nonce The nonce of the transaction.
    /// @param deadline The deadline of the transaction signature.
    /// @param signer The signer of the transaction.
    /// @param signature The signature of the transaction, EIP-712 encoded.
    event ExecutedWithSig(
        address indexed to,
        uint256 value,
        bytes data,
        uint256 nonce,
        uint256 deadline,
        address indexed signer,
        bytes signature
    );

    /// @notice Returns the IPAccount's internal nonce for transaction ordering.
    function state() external view returns (uint256);

    /// @notice Returns the identifier of the non-fungible token which owns the account
    /// @return chainId The EIP-155 ID of the chain the token exists on
    /// @return tokenContract The contract address of the token
    /// @return tokenId The ID of the token
    function token() external view returns (uint256, address, uint256);

    /// @notice Checks if the signer is valid for the given data
    /// @param signer The signer to check
    /// @param data The data to check against
    /// @return The function selector if the signer is valid, 0 otherwise
    function isValidSigner(address signer, bytes calldata data) external view returns (bytes4);

    /// @notice Returns the owner of the IP Account.
    /// @return owner The address of the owner.
    function owner() external view returns (address);

    /// @notice Executes a transaction from the IP Account on behalf of the signer.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether to send.
    /// @param data The data to send along with the transaction.
    /// @param signer The signer of the transaction.
    /// @param deadline The deadline of the transaction signature.
    /// @param signature The signature of the transaction, EIP-712 encoded.
    /// @return result The return data from the transaction.
    function executeWithSig(
        address to,
        uint256 value,
        bytes calldata data,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external payable returns (bytes memory);

    /// @notice Executes a transaction from the IP Account.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether to send.
    /// @param data The data to send along with the transaction.
    /// @return result The return data from the transaction.
    function execute(address to, uint256 value, bytes calldata data) external payable returns (bytes memory);
}
