// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IModule } from "../base/IModule.sol";

interface ITokenManagementModule is IModule {
    function transferERC20(address payable ipAccount, address to, address tokenContract, uint256 amount) external;

    function transferERC721(address payable ipAccount, address to, address tokenContract, uint256 tokenId) external;

    function transferERC1155(
        address payable ipAccount,
        address to,
        address tokenContract,
        uint256 tokenId,
        uint256 amount
    ) external;
}
