// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// contracts
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { BaseLicensingFramework } from "contracts/modules/licensing/BaseLicensingFramework.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

import "forge-std/console2.sol";

struct MockLicensingFrameworkConfig {
    address licenseRegistry;
    string licenseUrl;
    bool supportVerifyLink;
    bool supportVerifyMint;
    bool supportVerifyTransfer;
}

struct MockPolicy {
    bool returnVerifyLink;
    bool returnVerifyMint;
    bool returnVerifyTransfer;
}

contract MockLicensingFramework is
    BaseLicensingFramework,
    ILinkParamVerifier,
    IMintParamVerifier,
    ITransferParamVerifier
{
    MockLicensingFrameworkConfig internal config;

    constructor(MockLicensingFrameworkConfig memory conf)
        BaseLicensingFramework(conf.licenseRegistry, conf.licenseUrl) {
        config = conf;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, BaseLicensingFramework) returns (bool) {
        console2.log("MockLicensingFramework.supportsInterface");
        console2.logBytes4(interfaceId);
        console2.log("IParamVerifier");
        console2.logBytes4(type(IParamVerifier).interfaceId);
        console2.log("ILinkParamVerifier");
        console2.logBytes4(type(ILinkParamVerifier).interfaceId);
        console2.log("IMintParamVerifier");
        console2.logBytes4(type(IMintParamVerifier).interfaceId);
        console2.log("ITransferParamVerifier");
        console2.logBytes4(type(ITransferParamVerifier).interfaceId);

        if (interfaceId == type(IParamVerifier).interfaceId) return true;
        if (interfaceId == type(ILinkParamVerifier).interfaceId) return config.supportVerifyLink;
        if (interfaceId == type(IMintParamVerifier).interfaceId) return config.supportVerifyMint;
        if (interfaceId == type(ITransferParamVerifier).interfaceId) return config.supportVerifyTransfer;
        return super.supportsInterface(interfaceId);
    }

    function verifyMint(
        address,
        bool,
        address,
        address,
        uint256,
        bytes memory data
    ) external view returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyMint;
    }

    function verifyLink(uint256, address, address, address, bytes calldata data) external pure override returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyLink;
    }

    function verifyTransfer(
        uint256,
        address,
        address,
        uint256,
        bytes memory data
    ) external pure override returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyTransfer;
    }

    function policyToJson(bytes memory policyData) public pure returns (string memory) {
        return "MockLicensingFramework";
    }

}
