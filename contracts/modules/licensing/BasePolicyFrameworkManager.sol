// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
// contracts
import { IPolicyFrameworkManager } from "../../interfaces/modules/licensing/IPolicyFrameworkManager.sol";
import { LicensingModuleAware } from "../../modules/licensing/LicensingModuleAware.sol";

/// @title BasePolicyFrameworkManager
/// @notice Base contract for policy framework managers.
abstract contract BasePolicyFrameworkManager is IPolicyFrameworkManager, ERC165, LicensingModuleAware {
    /// @notice Returns the name to be show in license NFT (LNFT) metadata
    string public override name;

    /// @notice Returns the URL to the off chain legal agreement template text
    string public override licenseTextUrl;

    constructor(address licensing, string memory name_, string memory licenseTextUrl_) LicensingModuleAware(licensing) {
        name = name_;
        licenseTextUrl = licenseTextUrl_;
    }

    /// @notice IERC165 interface support.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IPolicyFrameworkManager).interfaceId || super.supportsInterface(interfaceId);
    }
}
