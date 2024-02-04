// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

// contracts
import { IPolicyFrameworkManager } from "contracts/interfaces/licensing/IPolicyFrameworkManager.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { LicenseRegistryAware } from "contracts/modules/licensing/LicenseRegistryAware.sol";

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title BasePolicyFrameworkManager
/// @notice Base contract for policy framework managers.
abstract contract BasePolicyFrameworkManager is IPolicyFrameworkManager, ERC165, LicenseRegistryAware {
    
    string public override name;
    string public override licenseTextUrl;

    /// @notice Initializes the base contract.
    /// @param registry The address of the license registry.
    constructor(address registry, string memory name_, string memory licenseTextUrl_) LicenseRegistryAware(registry) {
        name = name_;
        licenseTextUrl = licenseTextUrl_;
    }

    /// @notice ERC165 interface identifier for the policy framework manager.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IPolicyFrameworkManager).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice returns the address of the license registry
    function licenseRegistry() external view virtual override returns (address) {
        return address(LICENSE_REGISTRY);
    }
}
