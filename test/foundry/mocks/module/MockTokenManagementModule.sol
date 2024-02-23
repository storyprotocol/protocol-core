// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { IModule } from "../../../../contracts/interfaces/modules/base/IModule.sol";
import { IModuleRegistry } from "../../../../contracts/interfaces/registries/IModuleRegistry.sol";
import { IIPAccountRegistry } from "../../../../contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IPAccountChecker } from "../../../../contracts/lib/registries/IPAccountChecker.sol";
import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";
import { AccessControlled } from "../../../../contracts/access/AccessControlled.sol";

contract MockTokenManagementModule is BaseModule, AccessControlled {
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;

    IModuleRegistry public moduleRegistry;

    constructor(
        address _accessController,
        address _ipAccountRegistry,
        address _moduleRegistry
    ) AccessControlled(_accessController, _ipAccountRegistry) {
        moduleRegistry = IModuleRegistry(_moduleRegistry);
    }

    function name() external pure returns (string memory) {
        return "MockTokenManagementModule";
    }

    function transferERC721Token(
        address payable ipAccount,
        address to,
        address tokenContract,
        uint256 tokenId
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", ipAccount, to, tokenId)
        );
    }

    // transfer ERC1155 token
    function transferERC1155Token(
        address payable ipAccount,
        address to,
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256,uint256,bytes)",
                ipAccount,
                to,
                tokenId,
                amount,
                ""
            )
        );
    }

    // transfer ERC20 token
    function transferERC20Token(
        address payable ipAccount,
        address to,
        address tokenContract,
        uint256 amount
    ) external verifyPermission(ipAccount) {
        IIPAccount(ipAccount).execute(
            tokenContract,
            0,
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
