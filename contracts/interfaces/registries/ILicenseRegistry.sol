// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";

/// @title ILicenseRegistry

interface ILicenseRegistry {

    /// @notice Emitted when a license is minted
    /// @param creator The address that created the license
    /// @param receiver The address that received the license
    /// @param licenseId The id of the license
    /// @param amount The amount of licenses minted
    /// @param licenseData The license data
    event LicenseMinted(
        address indexed creator,
        address indexed receiver,
        uint256 indexed licenseId,
        uint256 amount,
        Licensing.License licenseData
    );

    function setLicensingModule(address newLicensingModule) external;

    function licensingModule() external view returns (address);

    /// @notice Mints a license to create derivative IP
    /// @param policyId The id of the policy with the licensing parameters
    /// @param licensorIpId The id of the licensor IP
    /// @param transferable True if the license is transferable
    /// @param amount The amount of licenses to mint
    /// @param receiver The address that will receive the license
    function mintLicense(
        uint256 policyId,
        address licensorIpId,
        bool transferable,
        uint256 amount,
        address receiver
    ) external returns (uint256 licenseId);

    function burnLicenses(address holder, uint256[] calldata licenseIds) external;

    ///
    /// Getters
    ///

    function mintedLicenses() external view returns (uint256);

    /// @notice True if holder is the licensee for the license (owner of the license NFT), or derivative IP owner if
    /// the license was added to the IP by linking (burning a license)
    function isLicensee(uint256 licenseId, address holder) external view returns (bool);
    
    /// @notice IP ID of the licensor for the license (parent IP)
    function licensorIpId(uint256 licenseId) external view returns (address);

    function policyIdForLicense(uint256 licenseId) external view returns (uint256);

    /// @notice License data (licensor, policy...) for the license id
    function license(uint256 licenseId) external view returns (Licensing.License memory);

}
