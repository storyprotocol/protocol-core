// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

// contracts
import { IPolicyFrameworkManager } from "../../interfaces/modules/licensing/IPolicyFrameworkManager.sol";
import { Licensing } from "../../lib/Licensing.sol";
import { Errors } from "../../lib/Errors.sol";
import { LicensingModuleAware } from "../../modules/licensing/LicensingModuleAware.sol";

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title BasePolicyFrameworkManager
/// @notice Base contract for policy framework managers.
abstract contract BasePolicyFrameworkManager is IPolicyFrameworkManager, ERC165, LicensingModuleAware {
    string public override name;
    string public override licenseTextUrl;

    /// @notice Initializes the base contract.
    /// @param licensing The address of the license LicensingModule.
    constructor(address licensing, string memory name_, string memory licenseTextUrl_) LicensingModuleAware(licensing) {
        name = name_;
        licenseTextUrl = licenseTextUrl_;
    }

    /// @notice ERC165 interface identifier for the policy framework manager.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IPolicyFrameworkManager).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice returns the address of the license registry
    function licensingModule() external view virtual override returns (address) {
        return address(LICENSING_MODULE);
    }
}
