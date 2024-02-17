// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

import { IPolicyFrameworkManager } from "../interfaces/modules/licensing/IPolicyFrameworkManager.sol";
import { ILicenseRegistry } from "../interfaces/registries/ILicenseRegistry.sol";
import { ILicensingModule } from "../interfaces/modules/licensing/ILicensingModule.sol";
import { Governable } from "../governance/Governable.sol";
import { Errors } from "../lib/Errors.sol";
import { Licensing } from "../lib/Licensing.sol";
import { DataUniqueness } from "../lib/DataUniqueness.sol";

/// @title LicenseRegistry aka LNFT
/// @notice Registry of License NFTs, which represent licenses granted by IP ID licensors to create derivative IPs.
contract LicenseRegistry is ERC1155, ILicenseRegistry, Governable {
    // TODO: deploy with CREATE2 to make this immutable
    ILicensingModule private _licensingModule;

    mapping(bytes32 licenseHash => uint256 ids) private _hashedLicenses;
    mapping(uint256 licenseIds => Licensing.License licenseData) private _licenses;
    /// This tracks the number of licenses registered in the protocol, it will not decrease when a license is burnt.
    uint256 private _mintedLicenses;

    /// @dev We have to implement this modifier instead of inheriting `LicensingModuleAware` because LicensingModule
    /// constructor requires the licenseRegistry address, which would create a circular dependency. Thus, we use the
    /// function `setLicensingModule` to set the licensing module address after deploying the module.
    modifier onlyLicensingModule() {
        if (msg.sender != address(_licensingModule)) {
            revert Errors.LicenseRegistry__CallerNotLicensingModule();
        }
        _;
    }

    constructor(address governance) ERC1155("") Governable(governance) {}

    function setLicensingModule(address newLicensingModule) external onlyProtocolAdmin {
        if (newLicensingModule == address(0)) {
            revert Errors.LicenseRegistry__ZeroLicensingModule();
        }
        _licensingModule = ILicensingModule(newLicensingModule);
    }

    function licensingModule() external view override returns (address) {
        return address(_licensingModule);
    }

    /// Mints license NFTs representing a policy granted by a set of ipIds (licensors). This NFT needs to be burned
    /// in order to link a derivative IP with its parents.
    /// If this is the first combination of policy and licensors, a new licenseId
    /// will be created.
    /// If not, the license is fungible and an id will be reused.
    /// Only callable by the LicensingModule.
    /// @param policyId id of the policy to be minted
    /// @param licensorIp IP Id granting the license
    /// @param transferable True if the license is transferable
    /// @param amount of licenses to be minted. License NFT is fungible for same policy and same licensors
    /// @param receiver of the License NFT(s).
    /// @return licenseId of the NFT(s).
    function mintLicense(
        uint256 policyId,
        address licensorIp,
        bool transferable,
        uint256 amount, // mint amount
        address receiver
    ) external onlyLicensingModule returns (uint256 licenseId) {
        Licensing.License memory licenseData = Licensing.License({
            policyId: policyId,
            licensorIpId: licensorIp,
            transferable: transferable
        });
        bool isNew;
        (licenseId, isNew) = DataUniqueness.addIdOrGetExisting(
            abi.encode(licenseData),
            _hashedLicenses,
            _mintedLicenses
        );
        if (isNew) {
            _mintedLicenses = licenseId;
            _licenses[licenseId] = licenseData;
            emit LicenseMinted(msg.sender, receiver, licenseId, amount, licenseData);
        }
        _mint(receiver, licenseId, amount, "");
        return licenseId;
    }

    function burnLicenses(address holder, uint256[] calldata licenseIds) external onlyLicensingModule {
        uint256[] memory values = new uint256[](licenseIds.length);
        for (uint256 i = 0; i < licenseIds.length; i++) {
            values[i] = 1;
        }
        // Burn licenses
        _burnBatch(holder, licenseIds, values);
    }

    function mintedLicenses() external view returns (uint256) {
        return _mintedLicenses;
    }

    /// Returns true if holder has positive balance for licenseId
    function isLicensee(uint256 licenseId, address holder) external view returns (bool) {
        return balanceOf(holder, licenseId) > 0;
    }

    function license(uint256 licenseId) external view returns (Licensing.License memory) {
        return _licenses[licenseId];
    }

    function licensorIpId(uint256 licenseId) external view returns (address) {
        return _licenses[licenseId].licensorIpId;
    }

    function policyIdForLicense(uint256 licenseId) external view returns (uint256) {
        return _licenses[licenseId].policyId;
    }

    /// @notice ERC1155 OpenSea metadata JSON representation of the LNFT parameters
    function uri(uint256 id) public view virtual override returns (string memory) {
        Licensing.License memory licenseData = _licenses[id];
        Licensing.Policy memory pol = _licensingModule.policy(licenseData.policyId);
        return IPolicyFrameworkManager(pol.policyFramework).policyToJson(pol.data);
    }

    /// @dev Pre-hook for ERC1155's _update() called on transfers.
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // We are interested in transfers, minting and burning are checked in mintLicense and
        // linkIpToParent in LicensingModule respectively
        if (from != address(0) && to != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                Licensing.License memory lic = _licenses[ids[i]];
                // TODO: Hook for verify transfer params
                if (!lic.transferable) {
                    // True if from == licensor
                    if (from != lic.licensorIpId) {
                        revert Errors.LicenseRegistry__NotTransferable();
                    }
                }
            }
        }
        super._update(from, to, ids, values);
    }
}
