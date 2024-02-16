// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Licensing } from "../../../lib/Licensing.sol";
import { IModule } from "../../modules/base/IModule.sol";
import { RoyaltyModule } from "../../../modules/royalty-module/RoyaltyModule.sol";
import { ILicenseRegistry } from "../../registries/ILicenseRegistry.sol";

/// @title ILicensingModule
interface ILicensingModule is IModule {
    /// @notice Status of a policy on IP asset
    /// @param index The local index of the policy in the IP asset
    /// @param isSet True if the policy is set in the IP asset
    /// @param active True if the policy is active
    /// @param isInherited True if the policy is inherited from a parent IP asset
    struct PolicySetup {
        uint256 index;
        bool isSet;
        bool active;
        bool isInherited;
    }

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

    /// @notice Returns the royalty module address
    function ROYALTY_MODULE() external view returns (RoyaltyModule);

    /// @notice Returns the license registry address
    function LICENSE_REGISTRY() external view returns (ILicenseRegistry);

    /// @notice Registers a policy framework manager into the contract, so it can add policy data for licenses.
    /// @param manager the address of the manager. Will be ERC165 checked for IPolicyFrameworkManager
    function registerPolicyFrameworkManager(address manager) external;

    /// @notice Registers a policy into the contract. MUST be called by a registered framework or it will revert.
    /// The policy data and its integrity must be verified by the policy framework manager.
    /// @param isLicenseTransferable True if the license is transferable
    /// @param data The policy data
    /// @return policyId The id of the policy
    function registerPolicy(bool isLicenseTransferable, bytes memory data) external returns (uint256 policyId);

    /// Adds a policy to an ipId, which can be used to mint licenses. Licenses are tradable permissions for ipIds to be
    /// derivatives (children). If policyId is not defined in the LicensingModule, reverts. Also reverts if ipId
    /// already has the same policy
    /// @param ipId The id of the IP asset
    /// @param polId The id of the policy
    /// @return indexOnIpId The index of the policy in the IP's policy list
    function addPolicyToIp(address ipId, uint256 polId) external returns (uint256 indexOnIpId);

    /// Mints license NFTs representing a policy granted by a set of ipIds (licensors).
    /// @param policyId The id of the policy to be minted
    /// @param licensorIpId The id of the IP granting the license (ie. licensor)
    /// @param amount Number of licenses to be minted. License NFT is fungible for same policy and same licensors
    /// @param receiver Receiver of the minted license NFT(s).
    /// @return licenseId New or reused id of the minted license NFT(s).
    function mintLicense(
        uint256 policyId,
        address licensorIpId,
        uint256 amount,
        address receiver
    ) external returns (uint256 licenseId);

    /// @notice Links an IP to the licensors listed in the license NFTs, if their policies allow it. Burns the license
    /// NFTs in the proccess. The caller must be the owner of the IP asset and license NFTs.
    /// @param licenseIds The id of the licenses to burn
    /// @param childIpId The id of the child IP to be linked
    /// @param minRoyalty The minimum derivative rev share that the child wants from its descendants. The value is
    /// overriden by the `derivativesRevShare` value of the linking licenses.
    function linkIpToParents(uint256[] calldata licenseIds, address childIpId, uint32 minRoyalty) external;

    ///
    /// Getters
    ///

    /// @notice Returns if the framework address is registered in the LicensingModule.
    /// @param framework The address of the policy framework manager
    /// @return isRegistered True if the framework is registered
    function isFrameworkRegistered(address framework) external view returns (bool);

    /// @notice Returns amount of distinct licensing policies in the LicensingModule.
    /// @return totalPolicies The amount of policies
    function totalPolicies() external view returns (uint256);

    /// @notice Returns the policy data for policyId, reverts if not found.
    /// @param policyId The id of the policy
    /// @return pol The policy data
    function policy(uint256 policyId) external view returns (Licensing.Policy memory pol);

    /// @notice Returns the policy id for the given policy data, or 0 if not found.
    /// @param framework The address of the policy framework manager
    /// @param isLicenseTransferable True if the license is transferable
    /// @param data The arbitrary policy data used by the framework
    /// @return policyId The id of the policy
    function getPolicyId(
        address framework,
        bool isLicenseTransferable,
        bytes memory data
    ) external view returns (uint256 policyId);

    /// @notice Returns the policy aggregator data for the given IP ID in the framework.
    /// @param framework The address of the policy framework manager
    /// @param ipId The id of the IP asset
    /// @return data The encoded policy aggregator data to be decoded by the framework manager
    function policyAggregatorData(address framework, address ipId) external view returns (bytes memory);

    /// @notice Returns if policyId exists in the LicensingModule
    /// @param policyId The id of the policy
    /// @return isDefined True if the policy is defined
    function isPolicyDefined(uint256 policyId) external view returns (bool);

    /// @notice Returns the policy ids attached to an IP
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset
    /// @return policyIds The ids of policy ids for the IP
    function policyIdsForIp(bool isInherited, address ipId) external view returns (uint256[] memory policyIds);

    /// @notice Returns the total number of policies attached to an IP
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset
    /// @return totalPolicies The total number of policies for the IP
    function totalPoliciesForIp(bool isInherited, address ipId) external view returns (uint256);

    /// @notice Returns if a given policyId is attached to an IP
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset
    /// @param policyId The id of the policy
    /// @return isSet True if the policy is set in the IP asset
    function isPolicyIdSetForIp(bool isInherited, address ipId, uint256 policyId) external view returns (bool);

    /// @notice Returns the policy ID for an IP by index on the IP's policy list
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset
    /// @param index The local index of a policy in the IP's policy list
    /// @return policyId The id of the policy
    function policyIdForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (uint256 policyId);

    /// @notice Returns the policy data for an IP by the policy's local index on the IP's policy list
    /// @param isInherited True if the policy is inherited from a parent IP
    /// @param ipId The id of the IP asset
    /// @param index The local index of a policy in the IP's policy list
    /// @return policy The policy data
    function policyForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (Licensing.Policy memory);

    /// @notice Returns the status of a policy in an IP's policy list
    /// @param ipId The id of the IP asset
    /// @param policyId The id of the policy
    /// @return index The local index of the policy in the IP's policy list
    /// @return isInherited True if the policy is inherited from a parent IP
    /// @return active True if the policy is active
    function policyStatus(
        address ipId,
        uint256 policyId
    ) external view returns (uint256 index, bool isInherited, bool active);

    /// @notice Returns if a policy attached to an IP asset is inherited from any parent IP
    /// @param ipId The id of the IP asset
    /// @param policyId The id of the policy
    /// @return isPolicyInherited True if the policy is inherited from a parent IP
    function isPolicyInherited(address ipId, uint256 policyId) external view returns (bool);

    /// @notice Returns if an IP is a derivative of another IP
    /// @param parentIpId The id of the parent IP asset
    /// @param childIpId The id of the child IP asset
    /// @return isParent True if the child IP is a derivative of the parent IP
    function isParent(address parentIpId, address childIpId) external view returns (bool);

    /// @notice Returns the list of parent IP assets for a given child IP asset
    /// @param ipId The id of the child IP asset
    /// @return parentIpIds The ids of the parent IP assets
    function parentIpIds(address ipId) external view returns (address[] memory);

    /// @notice Returns the total number of parents for an IP asset
    /// @param ipId The id of the IP asset
    /// @return totalParents The total number of parent IP assets
    function totalParentsForIpId(address ipId) external view returns (uint256);
}
