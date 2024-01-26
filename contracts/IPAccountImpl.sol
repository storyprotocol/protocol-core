// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.23;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IAccessController } from "contracts/interfaces/IAccessController.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { AccessPermission } from "contracts/lib/AccessPermission.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MetaTx } from "contracts/lib/MetaTx.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title IPAccountImpl
/// @notice The Story Protocol's implementation of the IPAccount.
contract IPAccountImpl is IERC165, IIPAccount {
    address public accessController;

    uint256 public state;

    receive() external payable override(IERC6551Account) {}

    /// @notice Checks if the contract supports a specific interface
    /// @param interfaceId_ The interface identifier, as specified in ERC-165
    /// @return True if the contract supports the interface, false otherwise
    function supportsInterface(bytes4 interfaceId_) external pure returns (bool) {
        return (interfaceId_ == type(IIPAccount).interfaceId ||
            interfaceId_ == type(IERC6551Account).interfaceId ||
            interfaceId_ == type(IERC1155Receiver).interfaceId ||
            interfaceId_ == type(IERC721Receiver).interfaceId ||
            interfaceId_ == type(IERC165).interfaceId);
    }

    /// @notice Initializes the IPAccount with the given access controller
    /// @param accessController_ The address of the access controller
    // TODO: can only be called by IPAccountRegistry
    function initialize(address accessController_) external {
        require(accessController_ != address(0), "Invalid access controller");
        accessController = accessController_;
    }

    /// @notice Returns the identifier of the non-fungible token which owns the account
    /// @return chainId The EIP-155 ID of the chain the token exists on
    /// @return tokenContract The contract address of the token
    /// @return tokenId The ID of the token
    function token() public view override returns (uint256, address, uint256) {
        bytes memory footer = new bytes(0x60);
        // 0x4d = 77 bytes (ERC-1167 Header, address, ERC-1167 Footer, salt)
        // 0x60 = 96 bytes (chainId, tokenContract, tokenId)
        //    ERC-1167 Header               (10 bytes)
        //    <implementation (address)>    (20 bytes)
        //    ERC-1167 Footer               (15 bytes)
        //    <salt (uint256)>              (32 bytes)
        //    <chainId (uint256)>           (32 bytes)
        //    <tokenContract (address)>     (32 bytes)
        //    <tokenId (uint256)>           (32 bytes)
        assembly {
            extcodecopy(address(), add(footer, 0x20), 0x4d, 0x60)
        }

        return abi.decode(footer, (uint256, address, uint256));
    }

    /// @notice Checks if the signer is valid for the given data
    /// @param signer_ The signer to check
    /// @param data_ The data to check against
    /// @return The function selector if the signer is valid, 0 otherwise
    function isValidSigner(address signer_, bytes calldata data_) external view returns (bytes4) {
        if (_isValidSigner(signer_, address(0), data_)) {
            return IERC6551Account.isValidSigner.selector;
        }

        return bytes4(0);
    }

    /// @notice Returns the owner of the IP Account.
    /// @return The address of the owner.
    function owner() public view returns (address) {
        (uint256 chainId, address contractAddress, uint256 tokenId) = token();
        if (chainId != block.chainid) return address(0);
        return IERC721(contractAddress).ownerOf(tokenId);
    }

    /// @notice Checks if the signer is valid for the given data and recipient
    /// @dev It leverages the access controller to check the permission
    /// @param signer_ The signer to check
    /// @param to_ The recipient of the transaction
    /// @param data_ The calldata to check against
    /// @return True if the signer is valid, false otherwise
    function _isValidSigner(address signer_, address to_, bytes calldata data_) internal view returns (bool) {
        require(data_.length == 0 || data_.length >= 4, "Invalid calldata");
        bytes4 selector = bytes4(0);
        if (data_.length >= 4) {
            selector = bytes4(data_[:4]);
        }
        return IAccessController(accessController).checkPermission(address(this), signer_, to_, selector);
    }

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
    ) external payable returns (bytes memory result) {
        if (signer == address(0)) {
            revert Errors.IPAccount__InvalidSigner();
        }

        if (deadline < block.timestamp) {
            revert Errors.IPAccount__ExpiredSignature();
        }

        ++state;

        bytes32 digest = MessageHashUtils.toTypedDataHash(
            MetaTx.calculateDomainSeparator(),
            MetaTx.getExecuteStructHash(
                MetaTx.Execute({ to: to, value: value, data: data, nonce: state, deadline: deadline })
            )
        );

        if (!SignatureChecker.isValidSignatureNow(signer, digest, signature)) {
            revert Errors.IPAccount__InvalidSignature();
        }

        result = _execute(signer, to, value, data);
        emit ExecutedWithSig(to, value, data, state, deadline, signer, signature);
    }

    /// @notice Executes a transaction from the IP Account.
    /// @param to The recipient of the transaction.
    /// @param value The amount of Ether to send.
    /// @param data The data to send along with the transaction.
    /// @return result The return data from the transaction.
    function execute(address to, uint256 value, bytes calldata data) external payable returns (bytes memory result) {
        ++state;
        result = _execute(msg.sender, to, value, data);
        emit Executed(to, value, data, state);
    }

    function onERC721Received(address, address, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function _execute(
        address signer,
        address to,
        uint256 value,
        bytes calldata data
    ) internal returns (bytes memory result) {
        require(_isValidSigner(signer, to, data), "Invalid signer");

        bool success;
        (success, result) = to.call{ value: value }(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

}
