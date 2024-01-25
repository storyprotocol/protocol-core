// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

/// @title MetaTx

library MetaTx {
    string constant EIP712_DOMAIN_VERSION = "1";
    bytes32 constant EIP712_DOMAIN_VERSION_HASH = keccak256(bytes(EIP712_DOMAIN_VERSION));
    bytes32 constant EIP712_DOMAIN =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant EXECUTE = keccak256("Execute(address to,uint256 value,bytes data,uint256 nonce,uint256 deadline)");

    struct Execute {
        address to;
        uint256 value;
        bytes data;
        uint256 nonce;
        uint256 deadline;
    }

    function calculateDomainSeparator() internal view returns (bytes32) {
        return calculateDomainSeparator(address(this));
    }

    function calculateDomainSeparator(address ipAccount) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN,
                    keccak256("Story Protocol IP Account"),
                    EIP712_DOMAIN_VERSION_HASH,
                    block.chainid,
                    ipAccount
                )
            );
    }

    function getExecuteStructHash(Execute memory execute) internal pure returns (bytes32) {
        return
            keccak256(
            abi.encode(
                MetaTx.EXECUTE,
                execute.to,
                execute.value,
                keccak256(execute.data),
                execute.nonce,
                execute.deadline
            )
        );
    }
}
