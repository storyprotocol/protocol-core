// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.23;

// import { Licensing } from "contracts/lib/Licensing.sol";
// import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";

// /// @title Mock Licensing Module
// contract MockLicensingModule is ILicensingModule {
//     function licenseRegistry() external view returns (address) {}

//     function registerPolicyFrameworkManager(address manager) external {}

//     function registerPolicy(bool isLicenseTransferable, bytes memory data) external returns (uint256 policyId) {}

//     function addPolicyToIp(address ipId, uint256 polId) external returns (uint256 indexOnIpId) {}

//     function mintLicense(
//         uint256 policyId,
//         address licensorIpId,
//         uint256 amount,
//         address receiver
//     ) external returns (uint256 licenseId) {}

//     function linkIpToParents(uint256[] calldata licenseIds, address childIpId, uint32 minRoyalty) external {}

//     function isFrameworkRegistered(address framework) external view returns (bool) {}

//     function totalPolicies() external view returns (uint256) {}

//     function policy(uint256 policyId) external view returns (Licensing.Policy memory pol) {}

//     function isPolicyDefined(uint256 policyId) external view returns (bool) {}

//     function policyIdsForIp(bool isInherited, address ipId) external view returns (uint256[] memory policyIds) {}

//     function totalPoliciesForIp(bool isInherited, address ipId) external view returns (uint256) {}

//     function isPolicyIdSetForIp(bool isInherited, address ipId, uint256 policyId) external view returns (bool) {}

//     function getPolicyId(
//         address framework,
//         bool isLicenseTransferable,
//         bytes memory data
//     ) external view returns (uint256 policyId) {}

//     function policyIdForIpAtIndex(
//         bool isInherited,
//         address ipId,
//         uint256 index
//     ) external view returns (uint256 policyId) {}

//     function policyForIpAtIndex(
//         bool isInherited,
//         address ipId,
//         uint256 index
//     ) external view returns (Licensing.Policy memory) {}

//     function policyStatus(
//         address ipId,
//         uint256 policyId
//     ) external view returns (uint256 index, bool isInherited, bool active) {}

//     function policyAggregatorData(address framework, address ipId) external view returns (bytes memory) {}

//     function isParent(address parentIpId, address childIpId) external view returns (bool) {}

//     function parentIpIds(address ipId) external view returns (address[] memory) {}

//     function totalParentsForIpId(address ipId) external view returns (uint256) {}

//     function name() external view returns (string memory) {
//         return "LICENSING_MODULE";
//     }
// }
