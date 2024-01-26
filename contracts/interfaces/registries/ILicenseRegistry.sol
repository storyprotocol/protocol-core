// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";

interface ILicenseRegistry {
    event LicenseFrameworkCreated(
        address indexed creator,
        uint256 indexed frameworkId,
        Licensing.FrameworkCreationParams frameworkCreationParams
    );

    event PolicyCreated(address indexed creator, uint256 indexed policyId, Licensing.Policy policy);

    event PolicyAddedToIpId(
        address indexed caller,
        address indexed ipId,
        uint256 indexed policyId,
        uint256 index,
        bool setByLinking
    );

    event LicenseMinted(
        address indexed creator,
        address indexed receiver,
        uint256 indexed licenseId,
        uint256 amount,
        Licensing.License licenseData
    );

    event IpIdLinkedToParent(address indexed caller, address indexed ipId, address indexed parentIpId);

    function addLicenseFramework(
        Licensing.FrameworkCreationParams calldata fwCreation
    ) external returns (uint256 frameworkId);

    function addPolicyToIp(
        address ipId,
        Licensing.Policy memory pol
    ) external returns (uint256 policyId, bool isNew, uint256 indexOnIpId);

    function addPolicyToIp(address ipId, uint256 polId) external returns (uint256 indexOnIpId);

    function addPolicy(Licensing.Policy memory pol) external returns (uint256 policyId);

    function mintLicense(
        uint256 policyId,
        address licensorIpId,
        uint256 amount,
        address receiver
    ) external returns (uint256 licenseId);

    function linkIpToParent(uint256 licenseId, address childIpId, address holder) external;

    ///
    /// Getters
    ///

    function totalFrameworks() external view returns (uint256);

    function frameworkParam(uint256 frameworkId, string calldata name) external view returns (Licensing.Parameter memory);
    function frameworkUrl(uint256 frameworkId) external view returns (string memory);

    function totalPolicies() external view returns (uint256);

    function policy(uint256 policyId) external view returns (Licensing.Policy memory pol);

    function isPolicyDefined(uint256 policyId) external view returns (bool);

    function policyIdsForIp(address ipId) external view returns (uint256[] memory policyIds);

    function totalPoliciesForIp(address ipId) external view returns (uint256);

    function isPolicyIdSetForIp(address ipId, uint256 policyId) external view returns (bool);

    function policyIdForIpAtIndex(address ipId, uint256 index) external view returns (uint256 policyId);

    function policyForIpAtIndex(address ipId, uint256 index) external view returns (Licensing.Policy memory);

    function indexOfPolicyForIp(address ipId, uint256 policyId) external view returns (uint256 index);
    
    function isPolicySetByLinking(address ipId, uint256 policyId) external view returns (bool);

    function isLicensee(uint256 licenseId, address holder) external view returns (bool);

    function licensorIpId(uint256 licenseId) external view returns (address);
    function license(uint256 licenseId) external view returns (Licensing.License memory);
    function isParent(address parentIpId, address childIpId) external view returns (bool);

    function parentIpIds(address ipId) external view returns (address[] memory);

    function totalParentsForIpId(address ipId) external view returns (uint256);
}
