// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "contracts/interfaces/modules/base/IModule.sol";

contract MockModule is IModule {
    function name() external pure returns(string memory) {
        return "MockModule";
    }

    function executeSuccessfully(string memory param) external pure returns(string memory) {
        return param;
    }

    function executeRevert() external pure {
        revert("MockModule: executeRevert");
    }
}
