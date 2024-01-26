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

contract MockParamVerifier is
    ERC165,
    BaseParamVerifier,
    IMintParamVerifier,
    ILinkParamVerifier,
    ITransferParamVerifier
{
    constructor(address licenseRegistry, string memory name) BaseParamVerifier(licenseRegistry, name) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IParamVerifier).interfaceId ||
            interfaceId == type(IMintParamVerifier).interfaceId ||
            interfaceId == type(ILinkParamVerifier).interfaceId ||
            interfaceId == type(ITransferParamVerifier).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external view override returns (bool) {
        return true;
    }

    function verifyMint(
        address,
        uint256,
        bool,
        address,
        address,
        uint256,
        bytes memory data
    ) external view returns (bool) {
        return abi.decode(data, (bool));
    }

    function verifyLink(uint256, address, address, address, bytes calldata data) external view override returns (bool) {
        return abi.decode(data, (bool));
    }

    function verifyTransfer(
        uint256,
        address,
        address,
        uint256,
        bytes memory data
    ) external view override returns (bool) {
        return abi.decode(data, (bool));
    }
}
