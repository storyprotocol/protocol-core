/* solhint-disable no-console */
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ERC6551Registry } from "lib/reference/src/ERC6551Registry.sol";
import { IERC6551Account } from "lib/reference/src/interfaces/IERC6551Account.sol";
// contracts
import { AccessController } from "contracts/AccessController.sol";
import { IPAccountImpl } from "contracts/IPAccountImpl.sol";
import { IIPAccount } from "contracts/interfaces/IIPAccount.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IPAccountRegistry } from "contracts/registries/IPAccountRegistry.sol";
import { IPRecordRegistry } from "contracts/registries/IPRecordRegistry.sol";
import { ModuleRegistry } from "contracts/registries/ModuleRegistry.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
// script
import { StringUtil } from "script/foundry/utils/StringUtil.sol";
import { BroadcastManager } from "script/foundry/utils/BroadcastManager.s.sol";
import { JsonDeploymentHandler } from "script/foundry/utils/JsonDeploymentHandler.s.sol";

contract Main is Script, BroadcastManager, JsonDeploymentHandler {
    using StringUtil for uint256;
    using stdJson for string;

    AccessController public accessController;

    IPAccountRegistry public ipAccountRegistry;
    IPRecordRegistry public ipRecordRegistry;
    LicenseRegistry public licenseRegistry;
    ModuleRegistry public moduleRegistry;
    // MockModule public module;

    IPAccountImpl public implementation;
    // MockERC721 nft = new MockERC721();

    IIPAccount public ipAccount;
    ERC6551Registry public erc6551Registry;

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
            _configureDeployment();
        }

        _writeDeployment("./deployments");
        _endBroadcast(); // BroadcastManager.s.sol
    }

    function _deployProtocolContracts(address accessControlAdmin) private {
        string memory contractKey;

        contractKey = "AccessController";
        _predeploy(contractKey);
        accessController = new AccessController();
        _postdeploy(contractKey, address(accessController));

        contractKey = "ERC6551Registry";
        _predeploy(contractKey);
        erc6551Registry = new ERC6551Registry();
        _postdeploy(contractKey, address(erc6551Registry));

        contractKey = "IPAccountImpl";
        _predeploy(contractKey);
        implementation = new IPAccountImpl();
        _postdeploy(contractKey, address(implementation));

        contractKey = "ModuleRegistry";
        _predeploy(contractKey);
        moduleRegistry = new ModuleRegistry();
        _postdeploy(contractKey, address(moduleRegistry));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        licenseRegistry = new LicenseRegistry("https://example.com/{id}.json");
        _postdeploy(contractKey, address(licenseRegistry));

        contractKey = "IPAccountRegistry";
        _predeploy(contractKey);
        ipAccountRegistry = new IPAccountRegistry(
            address(erc6551Registry),
            address(accessController),
            address(implementation)
        );
        _postdeploy(contractKey, address(ipAccountRegistry));

        contractKey = "LicenseRegistry";
        _predeploy(contractKey);
        ipRecordRegistry = new IPRecordRegistry(address(moduleRegistry), address(ipAccountRegistry));
        _postdeploy(contractKey, address(ipRecordRegistry));

        // mockModule = new MockModule(address(ipAccountRegistry), address(moduleRegistry), "MockModule");
    }

    function _predeploy(string memory contractKey) private {
        console2.log(string.concat("Deploying ", contractKey, "..."));
    }

    function _postdeploy(string memory contractKey, address newAddress) private {
        _writeAddress(contractKey, newAddress);
        console2.log(string.concat(contractKey, " deployed to:"), newAddress);
    }

    function _configureDeployment() private {
        _configureAccessController();
        // _configureModuleRegistry();
        // _configureLicenseRegistry();
        // _configureIPAccountRegistry();
        // _configureIPRecordRegistry();
    }

    function _configureAccessController() private {
        accessController.initialize(address(ipAccountRegistry), address(moduleRegistry));
    }
}
