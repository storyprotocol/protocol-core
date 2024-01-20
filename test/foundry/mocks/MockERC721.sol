// SPDX-License-Identifier: BUSDL-1.1
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "M721") {}

    function mint(address to, uint256 tokenId) external returns(uint256) {
        _safeMint(to, tokenId);
        return tokenId;
    }
}
