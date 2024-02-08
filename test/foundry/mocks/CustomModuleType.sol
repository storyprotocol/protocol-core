// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "contracts/interfaces/modules/base/IModule.sol";
import "contracts/interfaces/registries/IIPAccountRegistry.sol";
import "contracts/lib/registries/IPAccountChecker.sol";
import "contracts/interfaces/registries/IModuleRegistry.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {BaseModule} from "../../../contracts/modules/BaseModule.sol";

interface ICustomModule is IModule {
    function customFunction() external;
}

contract CustomModule is ICustomModule, BaseModule {
    string public constant override name = "CustomModule";

    function customFunction() external override {
        // do nothing
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return
            interfaceId == type(ICustomModule).interfaceId ||
            super.supportsInterface(interfaceId);
    }

}
