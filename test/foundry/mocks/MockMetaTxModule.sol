// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "contracts/interfaces/modules/base/IModule.sol";
import "contracts/interfaces/IIPAccount.sol";
import "contracts/interfaces/registries/IModuleRegistry.sol";
import "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IPAccountChecker } from "contracts/lib/registries/IPAccountChecker.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import "contracts/interfaces/IAccessController.sol";
import "contracts/lib/AccessPermission.sol";

contract MockMetaTxModule is IModule {
    using IPAccountChecker for IIPAccountRegistry;

    IIPAccountRegistry public ipAccountRegistry;
    IModuleRegistry public moduleRegistry;
    IAccessController accessController;

    constructor(address _ipAccountRegistry, address _moduleRegistry, address _accessController) {
        ipAccountRegistry = IIPAccountRegistry(_ipAccountRegistry);
        moduleRegistry = IModuleRegistry(_moduleRegistry);
        accessController = IAccessController(_accessController);
    }

    function name() external pure returns (string memory) {
        return "MockMetaTxModule";
    }

    function setPermissionThenCallOtherModules(
        address payable ipAccount,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bytes memory) {
        // check if ipAccount is valid
        require(ipAccountRegistry.isIpAccount(ipAccount), "MockMetaTxModule: ipAccount is not valid");
        address module1 = moduleRegistry.getModule("Module1WithPermission");
        // set permission
        IIPAccount(ipAccount).executeWithSig(
            address(accessController),
            0,
            abi.encodeWithSignature(
                "setPermission(address,address,address,bytes4,uint8)",
                ipAccount,
                address(this),
                module1,
                bytes4(0),
                AccessPermission.ALLOW
            ),
            signer,
            deadline,
            signature
        );
        // execute module1
        bytes memory module1Output = IIPAccount(ipAccount).execute(
            module1,
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", "test")
        );
        return module1Output;
    }

    function callAnotherModuleWithSignature(
        address payable ipAccount,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external returns (bytes memory) {
        // check if ipAccount is valid
        require(ipAccountRegistry.isIpAccount(ipAccount), "MockMetaTxModule: ipAccount is not valid");

        // call modules
        // workflow does have permission to call a module
        address module1 = moduleRegistry.getModule("Module1WithPermission");
        // execute module1
        bytes memory module1Output = IIPAccount(ipAccount).executeWithSig(
            module1,
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", "test"),
            signer,
            deadline,
            signature
        );
        return module1Output;
    }

    function workflowFailureWithSignature(
        address payable ipAccount,
        address signer,
        uint256 deadline,
        bytes calldata signature
    ) external {
        // check if ipAccount is valid
        require(ipAccountRegistry.isIpAccount(ipAccount), "MockModule: ipAccount is not valid");

        // call modules
        // workflow does have permission to call a module
        address module1 = moduleRegistry.getModule("Module1WithPermission");
        address module3WithoutPermission = moduleRegistry.getModule("Module3WithoutPermission");
        // workflow call 1st module
        bytes memory module1Output = IIPAccount(ipAccount).executeWithSig(
            module1,
            0,
            abi.encodeWithSignature("executeSuccessfully(string)", "test"),
            signer,
            deadline,
            signature
        );
        // workflow call 2nd module WITHOUT permission
        // the call should fail
        IIPAccount(ipAccount).execute(
            module3WithoutPermission,
            0,
            abi.encodeWithSignature("executeNoReturn(string)", abi.decode(module1Output, (string)))
        );
    }
}
