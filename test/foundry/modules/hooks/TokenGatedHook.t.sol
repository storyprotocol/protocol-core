// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import { TokenGatedHook } from "contracts/modules/hooks/TokenGatedHook.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";

contract TokenGatedHookTest is Test {
    TokenGatedHook public tokenGatedHook;
    MockERC721 nft = new MockERC721("MockERC721");
    address goodCaller = vm.addr(1);
    address badCaller = vm.addr(2);

    function setUp() public {
        tokenGatedHook = new TokenGatedHook();
        nft.mint(goodCaller);
    }

    function test_TokenGatedHook_CallerHasNFT() public {
        bytes memory data = abi.encode(address(nft));
        assertEq(tokenGatedHook.verify(goodCaller, data), true);
    }

    function test_TokenGatedHook_CallerDoesNotHaveNFT() public {
        bytes memory data = abi.encode(address(nft));
        assertEq(tokenGatedHook.verify(badCaller, data), false);
    }

    function test_TokenGatedHook_CallerHasNftTwice() public {
        bytes memory data = abi.encode(address(nft));
        assertEq(tokenGatedHook.verify(goodCaller, data), true);
        assertEq(tokenGatedHook.verify(goodCaller, data), true);
    }

    function test_TokenGatedHook_CallerHasNftThenBurnsIt() public {
        bytes memory data = abi.encode(address(nft));
        assertEq(tokenGatedHook.verify(goodCaller, data), true);
        vm.prank(goodCaller);
        nft.burn(1);
        assertEq(tokenGatedHook.verify(goodCaller, data), false);
    }

    function test_TokenGatedHook_CallerIsZeroAddress() public {
        bytes memory data = abi.encode(address(nft));
        assertEq(tokenGatedHook.verify(address(0), data), false);
    }

    function test_TokenGatedHook_InvalidNftCollectionAddress() public {
        bytes memory data = abi.encode(address(0x2222));
        assertEq(tokenGatedHook.verify(goodCaller, data), false);
    }
}
