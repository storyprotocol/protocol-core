// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IERC165, ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IHookModule } from "../../interfaces/modules/base/IHookModule.sol";

/// @title Token Gated Hook.
/// @notice Hook for ensursing caller is the owner of an NFT token.
contract TokenGatedHook is ERC165, IHookModule {
    using ERC165Checker for address;

    string public constant override name = "TokenGatedHook";

    function verify(address caller, bytes calldata data) external view returns (bool) {
        address tokenAddress = abi.decode(data, (address));
        if (caller == address(0)) {
            return false;
        }
        if (!tokenAddress.supportsInterface(type(IERC721).interfaceId)) {
            return false;
        }
        return IERC721(tokenAddress).balanceOf(caller) > 0;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IHookModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
