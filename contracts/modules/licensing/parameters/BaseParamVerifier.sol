// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

// contracts
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";

abstract contract BaseParamVerifier is IParamVerifier, ERC165 {
    using ShortStrings for *;
    /// @notice Gets the protocol-wide license registry.
    LicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Initializes the base module contract.
    /// @param licenseRegistry The address of the license registry.
    constructor(address licenseRegistry) {
        LICENSE_REGISTRY = LicenseRegistry(licenseRegistry);
    }

    /// @notice Modifier for authorizing the calling entity.
    modifier onlyLicenseRegistry() {
        if (msg.sender != address(LICENSE_REGISTRY)) {
            revert Errors.BaseParamVerifier__Unauthorized();
        }
        _;
    }

    function name() public view virtual override returns (bytes32);

    function nameString() external view override returns (string memory) {
        return ShortStringOps.bytes32ToString(name());
    }

    // TODO: implement flexible json()
    function json() external virtual override view returns (string memory) {
        return "";
    }
}
