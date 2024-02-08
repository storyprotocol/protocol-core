// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;
import "contracts/interfaces/IAccessController.sol";
import "contracts/interfaces/IIPAccount.sol";
import "contracts/lib/Errors.sol";

contract MockAccessController is IAccessController {
    bool public isAllowed = true;

    function setAllowed(bool _isAllowed) external {
        isAllowed = _isAllowed;
    }
    function setGlobalPermission(address signer_, address to_, bytes4 func_, uint8 permission_) external {}

    function setPermission(address, address, address, bytes4, uint8) external pure {}

    function getPermission(address, address, address, bytes4) external pure returns (uint8) {
        return 1;
    }

    function checkPermission(address ipAccount, address signer, address to, bytes4 func) external view {
        if (IIPAccount(payable(ipAccount)).owner() != signer || !isAllowed) {
            revert Errors.AccessController__PermissionDenied(ipAccount, signer, to, func);
        }
    }

    function setBatchPermissions(AccessPermission.Permission[] memory permissions) external {}
}
