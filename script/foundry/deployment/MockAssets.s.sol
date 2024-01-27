/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
// contracts
import { MockERC20 } from "contracts/mocks/MockERC20.sol";
import { MockERC721 } from "contracts/mocks/MockERC721.sol";
// script
import { BroadcastManager } from "script/foundry/utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "script/foundry/utils/JsonDeploymentHandler.s.sol";

contract MockAssets is Script, BroadcastManager, JsonDeploymentHandler {
    using stdJson for string;

    constructor() JsonDeploymentHandler("main") {}

    /// @dev To use, run the following command (e.g. for Sepolia):
    /// forge script script/foundry/deployment/Main.s.sol:Main --rpc-url $RPC_URL --broadcast --verify -vvvv

    function run() public {
        _beginBroadcast(); // BroadcastManager.s.sol

        bool configByMultisig = vm.envBool("DEPLOYMENT_CONFIG_BY_MULTISIG");
        console2.log("configByMultisig:", configByMultisig);

        if (configByMultisig) {
            _deployProtocolContracts(multisig);
        } else {
            _deployProtocolContracts(deployer);
        }

        _writeDeployment(); // write deployment json to deploy-out/deployment-{chainId}.json
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _deployProtocolContracts(address accessControlAdmin) private {
        _predeploy("MockERC20");
        MockERC20 mockERC20 = new MockERC20();
        _postdeploy("MockERC20", address(mockERC20));

        _predeploy("MockERC721");
        MockERC721 mockERC721 = new MockERC721();
        _postdeploy("MockERC721", address(mockERC721));
    }

    function _predeploy(string memory contractKey) private view {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }
}
