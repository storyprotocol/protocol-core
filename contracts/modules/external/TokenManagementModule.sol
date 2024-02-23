// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IIPAccountRegistry } from "../../interfaces/registries/IIPAccountRegistry.sol";
import { ITokenManagementModule } from "../../interfaces/modules/external/ITokenManagementModule.sol";
import { IPAccountChecker } from "../../lib/registries/IPAccountChecker.sol";
import { TOKEN_MANAGEMENT_MODULE_KEY } from "../../lib/modules/Module.sol";
import { BaseModule } from "../BaseModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";

contract TokenManagementModule is AccessControlled, BaseModule, ITokenManagementModule {
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;

    string public constant override name = TOKEN_MANAGEMENT_MODULE_KEY;

    constructor(
        address accessController,
        address ipAccountRegistry
    ) AccessControlled(accessController, ipAccountRegistry) {}

    function transferERC20(
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

    function transferERC721(
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

    function transferERC1155(
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
}
