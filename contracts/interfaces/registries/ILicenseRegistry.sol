// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Licensing } from "contracts/lib/Licensing.sol";

/// @title ILicenseRegistry
/// @notice Interface for the LicenseRegistry contract, which is the main entry point for the licensing system.
/// It is responsible for:
/// - Registering policy frameworks
/// - Registering policies
/// - Minting licenses
/// - Linking IP to its parent
/// - Verifying transfer parameters (through the ITransferParamVerifier interface implementation by the policy framework)
/// - Verifying linking parameters (through the ILinkParamVerifier interface implementation by the policy framework)
/// - Verifying policy parameters (through the IParamVerifier interface implementation by the policy framework)
interface ILicenseRegistry {

    /// @notice Emitted when a policy framework is created by registering a policy framework manager
    /// @param creator The address that created the policy framework
    /// @param frameworkId The id of the policy framework
    /// @param framework The policy framework data
    event PolicyFrameworkCreated(
        address indexed creator,
        uint256 indexed frameworkId,
        Licensing.PolicyFramework framework
    );
    /// @notice Emitted when a policy is added to the contract.
    /// @param creator The address that created the policy
    /// @param policyId The id of the policy
    /// @param policy The policy data
    event PolicyCreated(address indexed creator, uint256 indexed policyId, Licensing.Policy policy);

    /// @notice Emitted when a policy is added to an IP
    /// @param caller The address that called the function
    /// @param ipId The id of the IP
    /// @param policyId The id of the policy
    /// @param index The index of the policy in the IP's policy list
    /// @param inheritedPolicy Whether the policy was inherited from a parent IP (linking) or set by IP owner
    event PolicyAddedToIpId(
        address indexed caller,
        address indexed ipId,
        uint256 indexed policyId,
        uint256 index,
        bool inheritedPolicy
    );

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

    /// @notice Emitted when an IP is linked to its parent by burning a license
    /// @param caller The address that called the function
    /// @param ipId The id of the IP
    /// @param parentIpId The id of the parent IP
    event IpIdLinkedToParent(address indexed caller, address indexed ipId, address indexed parentIpId);

    /// @notice registers a policy framework into the contract
    /// @param fw The policy framework data
    /// @return frameworkId The id of the policy framework 
    function addPolicyFramework(Licensing.PolicyFramework calldata fw) external returns (uint256 frameworkId);

    /// @notice registers a policy into the contract
    /// @param pol The policy data
    /// @return policyId The id of the policy
    function addPolicy(Licensing.Policy memory pol) external returns (uint256 policyId);

    /// @notice adds a policy to an IP policy list
    /// @param ipId The id of the IP
    /// @param polId The id of the policy
    /// @return indexOnIpId The index of the policy in the IP's policy list
    function addPolicyToIp(address ipId, uint256 polId) external returns (uint256 indexOnIpId);

    /// @notice mints a license to create derivative IP
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

    /// @notice links an IP to its parent IP, burning the license NFT and the policy allows it
    /// @param licenseId The id of the license to burn
    /// @param childIpId The id of the child IP
    /// @param holder The address that holds the license
    function linkIpToParent(uint256 licenseId, address childIpId, address holder) external;

    ///
    /// Getters
    ///

    /// @notice gets total number of policy frameworks in the contract
    function totalFrameworks() external view returns (uint256);
    /// @notice gets policy framework data by id
    function framework(uint256 frameworkId) external view returns (Licensing.PolicyFramework memory);
    /// @notice gets policy framework license template URL by id
    function frameworkUrl(uint256 frameworkId) external view returns (string memory);
    /// @notice gets total number of policies (framework parameter configurations) in the contract
    function totalPolicies() external view returns (uint256);
    /// @notice gets policy data by id
    function policy(uint256 policyId) external view returns (Licensing.Policy memory pol);
    /// @notice true if policy is defined in the contract
    function isPolicyDefined(uint256 policyId) external view returns (bool);
    /// @notice gets the policy ids for an IP
    function policyIdsForIp(address ipId) external view returns (uint256[] memory policyIds);
    /// @notice gets total number of policies for an IP
    function totalPoliciesForIp(address ipId) external view returns (uint256);
    /// @notice true if policy is part of an IP's policy list
    function isPolicyIdSetForIp(address ipId, uint256 policyId) external view returns (bool);
    /// @notice gets the policy ID for an IP by index on the IP's policy list
    function policyIdForIpAtIndex(address ipId, uint256 index) external view returns (uint256 policyId);
    /// @notice gets the policy for an IP by index on the IP's policy list
    function policyForIpAtIndex(address ipId, uint256 index) external view returns (Licensing.Policy memory);
    /// @notice gets the index of a policy in an IP's policy list
    function indexOfPolicyForIp(address ipId, uint256 policyId) external view returns (uint256 index);
    /// @notice true if the license was added to the IP by linking (burning a license)
    function isPolicyInherited(address ipId, uint256 policyId) external view returns (bool);
    /// @notice true if holder is the licensee for the license (owner of the license NFT), or derivative IP owner if
    /// the license was added to the IP by linking (burning a license)
    function isLicensee(uint256 licenseId, address holder) external view returns (bool);
    /// @notice IP ID of the licensor for the license (parent IP)
    function licensorIpId(uint256 licenseId) external view returns (address);
    /// @notice license data (licensor, policy...) for the license id
    function license(uint256 licenseId) external view returns (Licensing.License memory);
    /// @notice true if an IP is a derivative of another IP
    function isParent(address parentIpId, address childIpId) external view returns (bool);
    /// @notice returns the parent IP IDs for an IP ID
    function parentIpIds(address ipId) external view returns (address[] memory);
    /// @notice total number of parents for an IP ID
    function totalParentsForIpId(address ipId) external view returns (uint256);
}