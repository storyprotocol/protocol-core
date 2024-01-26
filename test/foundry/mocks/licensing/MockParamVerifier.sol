// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// contracts
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { BaseParamVerifier } from "contracts/modules/licensing/parameters/BaseParamVerifier.sol";

struct MockParamVerifierConfig {
    address licenseRegistry;
    string name;
    bool supportVerifyLink;
    bool supportVerifyMint;
    bool supportVerifyTransfer;
}

contract MockParamVerifier is
    ERC165,
    BaseParamVerifier,
    ILinkParamVerifier,
    IMintParamVerifier,
    ITransferParamVerifier
{
    MockParamVerifierConfig internal config;

    constructor(MockParamVerifierConfig memory conf) BaseParamVerifier(conf.licenseRegistry, conf.name) {
        config = conf;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        if (interfaceId == type(IParamVerifier).interfaceId) return true;
        if (interfaceId == type(ILinkParamVerifier).interfaceId) return config.supportVerifyLink;
        if (interfaceId == type(IMintParamVerifier).interfaceId) return config.supportVerifyMint;
        if (interfaceId == type(ITransferParamVerifier).interfaceId) return config.supportVerifyTransfer;
        return super.supportsInterface(interfaceId);
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external pure override returns (bool) {
        return true;
    }

    function isCommercial() external pure override returns (bool) {
        return false;
    }

    function verifyMint(
        address,
        uint256,
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
}
