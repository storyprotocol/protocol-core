// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";

/// @title IIPAccount
/// @dev IPAccount is a token-bound account that adopts the EIP-6551 standard.
/// These accounts are deployed at deterministic addresses through the official 6551 account registry.
/// As a deployed smart contract, IPAccount can store IP-related information,
/// like ownership of other NFTs such as license NFT or Royalty NFT.
/// IPAccount can interact with modules by making calls as a normal transaction sender.
/// This allows for seamless operations on the state and data of IP.
/// IPAccount is core identity for all actions.
interface IIPAccount is IERC6551Account, IERC721Receiver, IERC1155Receiver {
    /// @notice Executes a transaction from the IP Account.
    /// @param to_ The recipient of the transaction.
    /// @param value_ The amount of Ether to send.
    /// @param data_ The data to send along with the transaction.
    /// @return The return data from the transaction.
    function execute(address to_, uint256 value_, bytes calldata data_) external payable returns (bytes memory);

    /// @notice Executes a transaction from the IP Account on behalf of the signer.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether to send.
    /// @param data The data to send along with the transaction.
    /// @param signer The signer of the transaction.
    /// @param deadline The deadline of the transaction signature.
    /// @param signature The signature of the transaction, EIP-712 encoded.
    function executeWithSig(
        address to,
        uint256 value,
        bytes calldata data,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external payable returns (bytes memory);

    /// @notice Returns the owner of the IP Account.
    /// @return The address of the owner.
    function owner() external view returns (address);
}
