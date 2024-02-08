// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/interfaces/modules/base/IModule.sol";
import "contracts/interfaces/registries/IIPAccountRegistry.sol";
import "contracts/lib/registries/IPAccountChecker.sol";
import "contracts/interfaces/registries/IModuleRegistry.sol";

contract MockModule is IModule {
    using IPAccountChecker for IIPAccountRegistry;

    IIPAccountRegistry public ipAccountRegistry;
    IModuleRegistry public moduleRegistry;
    string public name;

    constructor(address _ipAccountRegistry, address _moduleRegistry, string memory _name) {
        ipAccountRegistry = IIPAccountRegistry(_ipAccountRegistry);
        moduleRegistry = IModuleRegistry(_moduleRegistry);
        name = _name;
    }

    function executeSuccessfully(string memory param) external view returns (string memory) {
        require(ipAccountRegistry.isIpAccount(msg.sender), "MockModule: caller is not ipAccount");
        return param;
    }

    function executeNoReturn(string memory) external view {
        require(ipAccountRegistry.isIpAccount(msg.sender), "MockModule: caller is not ipAccount");
    }

    function callAnotherModule(string memory moduleName) external returns (string memory) {
        require(ipAccountRegistry.isIpAccount(payable(msg.sender)), "MockModule: caller is not ipAccount");
        address moduleAddress = moduleRegistry.getModule(moduleName);
        bytes memory output = IIPAccount(payable(msg.sender)).execute(
            moduleAddress,
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", moduleName)
        );
        return abi.decode(output, (string));
    }

    function executeRevert() external pure {
        revert("MockModule: executeRevert");
    }
}
