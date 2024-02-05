// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

// contracts
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title LicensingModuleAware
/// @notice Base contract to be inherited by modules that need to access the license registry.
abstract contract LicensingModuleAware {
    /// @notice Gets the protocol-wide license registry.
    ILicensingModule public immutable LICENSING_MODULE;

    /// @notice Initializes the base module contract.
    /// @param licensingModule The address of the license registry.
    constructor(address licensingModule) {
        LICENSING_MODULE = ILicensingModule(licensingModule);
    }

    /// @notice Modifier for authorizing the calling entity.
    modifier onlyLicensingModule() {
        if (msg.sender != address(LICENSING_MODULE)) {
            revert Errors.LicensingModuleAware__CallerNotLicensingModule();
        }
        _;
    }
}