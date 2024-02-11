// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Licensing } from "../../../lib/Licensing.sol";
import { IModule } from "../../modules/base/IModule.sol";

/// @title ILicensingModule
/// @notice Interface for the LicensingModule contract, which is the main entry point for the licensing system.
/// It is responsible for:
/// - Registering policy frameworks
/// - Registering policies
/// - Minting licenses
/// - Linking IP to its parent
/// - Verifying linking parameters
/// - Verifying policy parameters
interface ILicensingModule is IModule {
    /// @notice Emitted when a policy framework is created by registering a policy framework manager
    /// @param framework The address of the IPolicyFrameworkManager
    /// @param framework The policy framework data
    event PolicyFrameworkRegistered(address indexed framework, string name, string licenseTextUrl);

    /// @notice Emitted when a policy is added to the contract
    /// @param policyFrameworkManager The address that created the policy
    /// @param policyId The id of the policy
    /// @param policy The encoded policy data
    event PolicyRegistered(address indexed policyFrameworkManager, uint256 indexed policyId, bytes policy);

    /// @notice Emitted when a policy is added to an IP
    /// @param caller The address that called the function
    /// @param ipId The id of the IP
    /// @param policyId The id of the policy
    /// @param index The index of the policy in the IP's policy list
    /// @param isInherited Whether the policy was inherited from a parent IP (linking) or set by IP owner
    event PolicyAddedToIpId(
        address indexed caller,
        address indexed ipId,
        uint256 indexed policyId,
        uint256 index,
        bool isInherited
    );

    /// @notice Emitted when an IP is linked to its parent by burning a license
    /// @param caller The address that called the function
    /// @param ipId The id of the IP
    /// @param parentIpIds The ids of the parent IPs
    event IpIdLinkedToParents(address indexed caller, address indexed ipId, address[] parentIpIds);

    /// @notice Returns the address of the LicenseRegistry
    function licenseRegistry() external view returns (address);
    /// @notice Registers a policy framework manager into the contract, so it can add policy data for
    /// licenses.
    /// @param manager the address of the manager. Will be ERC165 checked for IPolicyFrameworkManager
    function registerPolicyFrameworkManager(address manager) external;

    /// @notice Registers a policy into the contract. MUST be called by a registered
    /// framework or it will revert. The policy data and its integrity must be
    /// verified by the policy framework manager.
    /// @param isLicenseTransferable True if the license is transferable
    /// @param data The policy data
    function registerPolicy(bool isLicenseTransferable, bytes memory data) external returns (uint256 policyId);

    /// @notice returns the policy id for the given data, or 0 if not found
    function getPolicyId(
        address framework,
        bool isLicenseTransferable,
        bytes memory data
    ) external view returns (uint256 policyId);

    /// @notice Adds a policy to an IP policy list
    /// @param ipId The id of the IP
    /// @param polId The id of the policy
    /// @return indexOnIpId The index of the policy in the IP's policy list
    function addPolicyToIp(address ipId, uint256 polId) external returns (uint256 indexOnIpId);

    /// @notice Mints a license to create derivative IP
    /// @param policyId The id of the policy with the licensing parameters
    /// @param licensorIpId The id of the licensor IP
    /// @param amount The amount of licenses to mint
    /// @param receiver The address that will receive the license
    function mintLicense(
        uint256 policyId,
        address licensorIpId,
        uint256 amount,
        address receiver
    ) external returns (uint256 licenseId);

    /// @notice Links an IP to the licensors (parent IP IDs) listed in the License NFTs, if their policies allow it,
    /// burning the NFTs in the proccess. The caller must be the owner of the NFTs and the IP owner.
    /// @param licenseIds The id of the licenses to burn
    /// @param childIpId The id of the child IP to be linked
    /// @param minRoyalty The minimum derivative rev share that the child wants from its descendants. The value is
    /// overriden by the `derivativesRevShare` value of the linking licenses.
    function linkIpToParents(uint256[] calldata licenseIds, address childIpId, uint32 minRoyalty) external;

    ///
    /// Getters
    ///

    /// @notice True if the framework address is registered in LicenseRegistry
    function isFrameworkRegistered(address framework) external view returns (bool);

    /// @notice Gets total number of policies (framework parameter configurations) in the contract
    function totalPolicies() external view returns (uint256);

    /// @notice Gets policy data by id
    function policy(uint256 policyId) external view returns (Licensing.Policy memory pol);

    /// @notice True if policy is defined in the contract
    function isPolicyDefined(uint256 policyId) external view returns (bool);

    /// @notice Gets the policy ids for an IP
    function policyIdsForIp(bool isInherited, address ipId) external view returns (uint256[] memory policyIds);

    /// @notice Gets total number of policies for an IP
    function totalPoliciesForIp(bool isInherited, address ipId) external view returns (uint256);

    /// @notice True if policy is part of an IP's policy list
    function isPolicyIdSetForIp(bool isInherited, address ipId, uint256 policyId) external view returns (bool);

    /// @notice Gets the policy ID for an IP by index on the IP's policy list
    function policyIdForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (uint256 policyId);

    /// @notice Gets the policy for an IP by index on the IP's policy list
    function policyForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (Licensing.Policy memory);

    /// @notice Gets the status of a policy in an IP's policy list
    function policyStatus(
        address ipId,
        uint256 policyId
    ) external view returns (uint256 index, bool isInherited, bool active);

    function policyAggregatorData(address framework, address ipId) external view returns (bytes memory);

    /// @notice True if an IP is a derivative of another IP
    function isParent(address parentIpId, address childIpId) external view returns (bool);

    /// @notice Returns the parent IP IDs for an IP ID
    function parentIpIds(address ipId) external view returns (address[] memory);

    /// @notice Total number of parents for an IP ID
    function totalParentsForIpId(address ipId) external view returns (uint256);
}
