// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// contracts
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { BaseLicensingModule } from "contracts/modules/licensing/BaseLicensingModule.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

struct MockLicensingModuleConfig {
    address licenseRegistry;
    string licenseUrl;
    bool supportVerifyLink;
    bool supportVerifyMint;
    bool supportVerifyTransfer;
}

contract MockLicensingModule is
    ERC165,
    BaseLicensingModule,
    ILinkParamVerifier,
    IMintParamVerifier,
    ITransferParamVerifier
{
    MockLicensingModuleConfig internal config;

    constructor(MockLicensingModuleConfig memory conf)
        BaseLicensingModule(conf.licenseRegistry, conf.licenseUrl) {
        config = conf;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165, BaseLicensingModule) returns (bool) {
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
    ) external pure returns (bool) {
        return abi.decode(data, (bool));
    }

    function verifyLink(uint256, address, address, address, bytes calldata data) external pure override returns (bool) {
        return abi.decode(data, (bool));
    }

    function verifyTransfer(
        uint256,
        address,
        address,
        uint256,
        bytes memory data
    ) external pure override returns (bool) {
        return abi.decode(data, (bool));
    }

    function policyToJson(bytes memory policyData) public pure returns (string memory) {
        return "MockLicensingModule";
    }

}
