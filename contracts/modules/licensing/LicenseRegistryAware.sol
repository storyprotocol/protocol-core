// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

// contracts
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";

abstract contract LicenseRegistryAware {

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
            revert Errors.LicenseRegistryAware__CallerNotLicenseRegistry();
        }
        _;
    }

}
