// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

contract MockERC6551Registry {
    /**
     * @dev The registry SHALL emit the AccountCreated event upon successful account creation
     */
    event AccountCreated(
        address account,
        address indexed implementation,
        uint256 chainId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 salt
    );

    /**
     * @dev Creates a token bound account for a non-fungible token
     *
     * If account has already been created, returns the account address without calling create2
     *
     * If initData is not empty and account has not yet been created, calls account with
     * provided initData after creation
     *
     * Emits AccountCreated event
     *
     * @return the address of the account
     */
    function createAccount(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt,
        bytes calldata initData
    ) external returns (address) {
        bytes memory code = _getCreationCode(
            implementation,
            chainId,
            tokenContract,
            tokenId,
            salt
        );

        address _account = Create2.computeAddress(bytes32(salt), keccak256(code));

        if (_account.code.length != 0) return _account;

        emit AccountCreated(_account, implementation, chainId, tokenContract, tokenId, salt);

        _account = Create2.deploy(0, bytes32(salt), code);

        if (initData.length != 0) {
            (bool success, bytes memory result) = _account.call(initData);
            if (!success) {
                assembly {
                    revert(add(result, 32), mload(result))
                }
            }
        }

        return _account;
    }

    /**
     * @dev Returns the computed token bound account address for a non-fungible token
     *
     * @return The computed address of the token bound account
     */
    function account(
        address implementation,
        uint256 chainId,
        address tokenContract,
        uint256 tokenId,
        uint256 salt
    ) external view returns (address) {
        bytes32 bytecodeHash = keccak256(
            _getCreationCode(
                implementation,
                chainId,
                tokenContract,
                tokenId,
                salt
            )
        );

        return Create2.computeAddress(bytes32(salt), bytecodeHash);
    }

    function _getCreationCode(
        address implementation_,
        uint256 chainId_,
        address tokenContract_,
        uint256 tokenId_,
        uint256 salt_
    ) internal pure returns (bytes memory) {
        return
        // Proxy that delegate call to IPAccountProxy
        //    |           0x00000000      36             calldatasize          cds
        //    |           0x00000001      3d             returndatasize        0 cds
        //    |           0x00000002      3d             returndatasize        0 0 cds
        //    |           0x00000003      37             calldatacopy
        //    |           0x00000004      3d             returndatasize        0
        //    |           0x00000005      3d             returndatasize        0 0
        //    |           0x00000006      3d             returndatasize        0 0 0
        //    |           0x00000007      36             calldatasize          cds 0 0 0
        //    |           0x00000008      3d             returndatasize        0 cds 0 0 0
        //    |           0x00000009      73bebebebebe.  push20 0xbebebebe     0xbebe 0 cds 0 0 0
        //    |           0x0000001e      5a             gas                   gas 0xbebe 0 cds 0 0 0
        //    |           0x0000001f      f4             delegatecall          suc 0
        //    |           0x00000020      3d             returndatasize        rds suc 0
        //    |           0x00000021      82             dup3                  0 rds suc 0
        //    |           0x00000022      80             dup1                  0 0 rds suc 0
        //    |           0x00000023      3e             returndatacopy        suc 0
        //    |           0x00000024      90             swap1                 0 suc
        //    |           0x00000025      3d             returndatasize        rds 0 suc
        //    |           0x00000026      91             swap2                 suc 0 rds
        //    |           0x00000027      602b           push1 0x2b            0x2b suc 0 rds
        //    |       ,=< 0x00000029      57             jumpi                 0 rds
        //    |       |   0x0000002a      fd             revert
        //    |       `-> 0x0000002b      5b             jumpdest              0 rds
        //    \           0x0000002c      f3             return
            abi.encodePacked(
            hex"3d60ad80600a3d3981f3363d3d373d3d3d363d73",
            implementation_,
            hex"5af43d82803e903d91602b57fd5bf3",
            abi.encode(salt_, chainId_, tokenContract_, tokenId_)
        );
    }
}
