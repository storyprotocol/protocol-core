// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";

import { IERC6551Account } from "@erc6551/interfaces/IERC6551Account.sol";

import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { MockAccessController } from "test/foundry/mocks/MockAccessController.sol";
import { MockERC721 } from "test/foundry/mocks/MockERC721.sol";
import { MockModule } from "test/foundry/mocks/MockModule.sol";
import { Users, UsersLib } from "test/foundry/utils/Users.sol";

contract Integration_Flow_EmergenceUniverse_Test is Test {
    Users internal u;

    function setUp() public {
        u = UsersLib.createMockUsers(vm);
    }

    function test_IntegrationFlow_EmergenceUniverse() public {}
}
