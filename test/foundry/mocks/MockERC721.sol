// SPDX-License-Identifier: BUSDL-1.1
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    uint256 private _counter;

    constructor() ERC721("MockERC721", "M721") {
        _counter = 0;
    }

    function mint(address to) public returns (uint256 tokenId) {
        tokenId = ++_counter;
        _safeMint(to, tokenId);
        return tokenId;
    }

    function mintId(address to, uint256 tokenId) public {
        ++_counter;
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        _transfer(from, to, tokenId);
    }
}
