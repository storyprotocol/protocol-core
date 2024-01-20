// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "contracts/interfaces/IAccessController.sol";
import "contracts/interfaces/IIPAccount.sol";

contract MockAccessController is IAccessController {

    bool public isAllowed = true;

    function setAllowed(bool _isAllowed) external {
        isAllowed = _isAllowed;
    }

    function setPermission(address, address, address, bytes4, uint8) external pure {

    }

    function getPermission(address, address, address, bytes4) external pure returns (uint8) {
        return 1;
    }

    function checkPermission(address ipAccount, address signer, address, bytes4) external view returns(bool) {
        return IIPAccount(payable(ipAccount)).owner() == signer && isAllowed;
    }
}
