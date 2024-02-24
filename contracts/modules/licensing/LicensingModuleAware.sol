// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// contracts
import { ILicensingModule } from "../../interfaces/modules/licensing/ILicensingModule.sol";
import { Errors } from "../../lib/Errors.sol";

/// @title LicensingModuleAware
/// @notice Base contract to be inherited by modules that need to access the licensing module.
abstract contract LicensingModuleAware {
    /// @notice Returns the protocol-wide licensing module.
    ILicensingModule public immutable LICENSING_MODULE;

    constructor(address licensingModule) {
        LICENSING_MODULE = ILicensingModule(licensingModule);
    }

    /// @notice Modifier for authorizing the calling entity to only the LicensingModule.
    modifier onlyLicensingModule() {
        if (msg.sender != address(LICENSING_MODULE)) {
            revert Errors.LicensingModuleAware__CallerNotLicensingModule();
        }
        _;
    }
}
