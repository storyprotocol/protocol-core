// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { ILicensingModule } from "../../../../contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { ILicenseRegistry } from "../../../../contracts/interfaces/registries/ILicenseRegistry.sol";
import { IDisputeModule } from "../../../../contracts/interfaces/modules/dispute/IDisputeModule.sol";
import { DataUniqueness } from "../../../../contracts/lib/DataUniqueness.sol";
import { Licensing } from "../../../../contracts/lib/Licensing.sol";
import { RoyaltyModule } from "../../../../contracts/modules/royalty/RoyaltyModule.sol";
import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";

contract MockLicensingModule is BaseModule, ILicensingModule {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    RoyaltyModule public immutable ROYALTY_MODULE;
    ILicenseRegistry public immutable LICENSE_REGISTRY;
    IDisputeModule public immutable DISPUTE_MODULE;
    string public constant name = "LICENSING_MODULE";

    mapping(address framework => bool registered) private _registeredFrameworkManagers;
    mapping(bytes32 policyHash => uint256 policyId) private _hashedPolicies;
    mapping(uint256 policyId => Licensing.Policy policyData) private _policies;
    uint256 private _totalPolicies;
    mapping(address ipId => mapping(uint256 policyId => PolicySetup setup)) private _policySetups;
    mapping(bytes32 hashIpIdAnInherited => EnumerableSet.UintSet policyIds) private _policiesPerIpId;
    mapping(address ipId => EnumerableSet.AddressSet parentIpIds) private _ipIdParents;
    mapping(address framework => mapping(address ipId => bytes policyAggregatorData)) private _ipRights;

    constructor(address _royaltyModule, address _licenseRegistry) {
        ROYALTY_MODULE = RoyaltyModule(_royaltyModule);
        LICENSE_REGISTRY = ILicenseRegistry(_licenseRegistry);
    }

    function licenseRegistry() external view returns (address) {
        return address(LICENSE_REGISTRY);
    }

    function registerPolicyFrameworkManager(address manager) external {
        _registeredFrameworkManagers[manager] = true;
    }

    function registerPolicy(Licensing.Policy memory pol) external returns (uint256 policyId) {
        (uint256 polId, bool newPol) = DataUniqueness.addIdOrGetExisting(
            abi.encode(pol),
            _hashedPolicies,
            _totalPolicies
        );

        if (newPol) {
            _totalPolicies = polId;
            _policies[polId] = pol;
        }
        return polId;
    }

    function addPolicyToIp(address ipId, uint256 polId) public returns (uint256 indexOnIpId) {
        indexOnIpId = _addPolicyIdToIp({ ipId: ipId, policyId: polId, isInherited: false, skipIfDuplicate: false });
    }

    function mintLicense(
        uint256 policyId,
        address licensorIpId,
        uint256 amount,
        address receiver,
        bytes calldata royaltyContext
    ) external returns (uint256 licenseId) {
        Licensing.Policy memory pol = policy(policyId);
        licenseId = LICENSE_REGISTRY.mintLicense(policyId, licensorIpId, pol.isLicenseTransferable, amount, receiver);
    }

    function linkIpToParents(uint256[] calldata licenseIds, address childIpId, bytes calldata royaltyContext) external {
        LICENSE_REGISTRY.burnLicenses(childIpId, licenseIds);
    }

    function _addPolicyIdToIp(
        address ipId,
        uint256 policyId,
        bool isInherited,
        bool skipIfDuplicate
    ) private returns (uint256 index) {
        // Try and add the policy into the set.
        EnumerableSet.UintSet storage _pols = _policySetPerIpId(isInherited, ipId);
        if (!_pols.add(policyId)) {
            if (skipIfDuplicate) {
                return _policySetups[ipId][policyId].index;
            }
        }
        index = _pols.length() - 1;
        PolicySetup storage setup = _policySetups[ipId][policyId];
        setup.index = index;
        setup.isSet = true;
        setup.active = true;
        setup.isInherited = isInherited;
        return index;
    }

    function _linkIpToParent(uint256 policyId, address licensor, address childIpId) private {
        _addPolicyIdToIp({ ipId: childIpId, policyId: policyId, isInherited: true, skipIfDuplicate: true });
        _ipIdParents[childIpId].add(licensor);
    }

    function _policySetPerIpId(bool isInherited, address ipId) private view returns (EnumerableSet.UintSet storage) {
        return _policiesPerIpId[keccak256(abi.encode(isInherited, ipId))];
    }

    function isFrameworkRegistered(address policyFramework) external view returns (bool) {
        return _registeredFrameworkManagers[policyFramework];
    }

    function totalPolicies() external view returns (uint256) {
        return _totalPolicies;
    }

    function policy(uint256 policyId) public view returns (Licensing.Policy memory pol) {
        pol = _policies[policyId];
        return pol;
    }

    function getPolicyId(Licensing.Policy calldata pol) external view returns (uint256 policyId) {
        return _hashedPolicies[keccak256(abi.encode(pol))];
    }

    function policyAggregatorData(address framework, address ipId) external view returns (bytes memory) {
        return _ipRights[framework][ipId];
    }

    function isPolicyDefined(uint256 policyId) public view returns (bool) {
        return _policies[policyId].policyFramework != address(0);
    }

    function policyIdsForIp(bool isInherited, address ipId) external view returns (uint256[] memory policyIds) {
        return _policySetPerIpId(isInherited, ipId).values();
    }

    function totalPoliciesForIp(bool isInherited, address ipId) public view returns (uint256) {
        return _policySetPerIpId(isInherited, ipId).length();
    }

    function isPolicyIdSetForIp(bool isInherited, address ipId, uint256 policyId) external view returns (bool) {
        return _policySetPerIpId(isInherited, ipId).contains(policyId);
    }

    function policyIdForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (uint256 policyId) {
        return _policySetPerIpId(isInherited, ipId).at(index);
    }

    function policyForIpAtIndex(
        bool isInherited,
        address ipId,
        uint256 index
    ) external view returns (Licensing.Policy memory) {
        return _policies[_policySetPerIpId(isInherited, ipId).at(index)];
    }

    function policyStatus(
        address ipId,
        uint256 policyId
    ) external view returns (uint256 index, bool isInherited, bool active) {
        PolicySetup storage setup = _policySetups[ipId][policyId];
        return (setup.index, setup.isInherited, setup.active);
    }

    function isPolicyInherited(address ipId, uint256 policyId) external view returns (bool) {
        return _policySetups[ipId][policyId].isInherited;
    }

    function isParent(address parentIpId, address childIpId) external view returns (bool) {
        return _ipIdParents[childIpId].contains(parentIpId);
    }

    function parentIpIds(address ipId) external view returns (address[] memory) {
        return _ipIdParents[ipId].values();
    }

    function totalParentsForIpId(address ipId) external view returns (uint256) {
        return _ipIdParents[ipId].length();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(ILicensingModule).interfaceId || super.supportsInterface(interfaceId);
    }
}
