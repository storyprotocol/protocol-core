// SPDX-License-Identifier: UNLICENSED
// See https://github.com/storyprotocol/protocol-contracts/blob/main/StoryProtocol-AlphaTestingAgreement-17942166.3.pdf
pragma solidity ^0.8.23;

// contracts
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ILicensingModule } from "contracts/interfaces/licensing/ILicensingModule.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { LicenseRegistryAware } from "contracts/modules/licensing/LicenseRegistryAware.sol";

// external
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

abstract contract BaseLicensingModule is IParamVerifier, ILicensingModule, ERC165, LicenseRegistryAware {

    string public licenseUrl;

    uint256 public frameworkId;

    /// @notice Initializes the base module contract.
    /// @param registry The address of the license registry.
    constructor(address registry, string memory templateUrl) LicenseRegistryAware(registry) {
        licenseUrl = templateUrl;
    }

    function register() external returns(uint256) {
        Licensing.Framework memory framework = Licensing.Framework({
            licensingModule: address(this),
            licenseUrl: licenseUrl
        });
        frameworkId = LICENSE_REGISTRY.addLicenseFramework(framework);
        return frameworkId;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IParamVerifier).interfaceId ||
            interfaceId == type(ILicensingModule).interfaceId;
    }

    function licenseRegistry() virtual override external view returns (address) {
        return address(LICENSE_REGISTRY);
    }
}
