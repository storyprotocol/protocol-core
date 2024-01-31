// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

// contracts
import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/licensing/IPolicyFrameworkManager.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { LicenseRegistryAware } from "contracts/modules/licensing/LicenseRegistryAware.sol";

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title BasePolicyFrameworkManager
/// @notice Base contract for policy framework managers.
abstract contract BasePolicyFrameworkManager is IPolicyVerifier, IPolicyFrameworkManager, ERC165, LicenseRegistryAware {
    string public licenseUrl;

    uint256 public policyFrameworkId;

    /// @notice Initializes the base contract.
    /// @param registry The address of the license registry.
    /// @param templateUrl The URL for the license template.
    constructor(address registry, string memory templateUrl) LicenseRegistryAware(registry) {
        licenseUrl = templateUrl;
    }

    /// @notice Registers this policy framework manager within the license registry, to be able
    /// to add policies into the license registry.
    /// @dev save the policyFrameworkId in this PolicyFrameworkManager
    /// @return The ID of the policy framework.
    function register() external returns (uint256) {
        Licensing.PolicyFramework memory framework = Licensing.PolicyFramework({
            policyFramework: address(this),
            licenseUrl: licenseUrl
        });
        policyFrameworkId = LICENSE_REGISTRY.addPolicyFramework(framework);
        return policyFrameworkId;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IPolicyFrameworkManager).interfaceId || super.supportsInterface(interfaceId);
    }

    function licenseRegistry() external view virtual override returns (address) {
        return address(LICENSE_REGISTRY);
    }
}
