// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

// contracts
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

abstract contract BaseLicensingModule is IParamVerifier, ERC165 {

    /// @notice Gets the protocol-wide license registry.
    LicenseRegistry public immutable LICENSE_REGISTRY;

    uint256 public immutable FRAMEWORK_ID;

    /// @notice Initializes the base module contract.
    /// @param licenseRegistry The address of the license registry.
    constructor(address licenseRegistry, uint256 frameworkId) {
        LICENSE_REGISTRY = LicenseRegistry(licenseRegistry);
        FRAMEWORK_ID = frameworkId;
    }

    /// @notice Modifier for authorizing the calling entity.
    modifier onlyLicenseRegistry() {
        if (msg.sender != address(LICENSE_REGISTRY)) {
            revert Errors.BaseLicensingModule__Unauthorized();
        }
        _;
    }

}
