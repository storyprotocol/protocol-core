// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
// contracts
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";

// TODO: consider disabling operators/approvals on creation
contract LicenseRegistry is ERC1155, ILicenseRegistry {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for *;
    using Licensing for *;

    mapping(uint256 => Licensing.Framework) private _frameworks;
    uint256 private _totalFrameworks;

    mapping(bytes32 => uint256) private _hashedPolicies;
    mapping(uint256 => Licensing.Policy) private _policies;
    uint256 private _totalPolicies;
    // DO NOT remove policies, that rugs derivatives and breaks ordering assumptions in set
    mapping(address => EnumerableSet.UintSet) private _policiesPerIpId;
    mapping(address => bool[]) private _policyPerIpIdSetByLinking;
    
    mapping(address => EnumerableSet.AddressSet) private _ipIdParents;

    mapping(bytes32 => uint256) private _hashedLicenses;
    mapping(uint256 => Licensing.License) private _licenses;

    /// This tracks the number of licenses registered in the protocol, it will not decrease when a license is burnt.
    uint256 private _totalLicenses;

    modifier onlyLicensee(uint256 licenseId, address holder) {
        // Should ERC1155 operator count? IMO is a security risk. Better use ACL
        if (balanceOf(holder, licenseId) == 0) {
            revert Errors.LicenseRegistry__NotLicensee();
        }
        _;
    }

    constructor(string memory uri) ERC1155(uri) {}

    /// Adds a license framework to Story Protocol.
    /// Must be called by protocol admin
    /// @param fwCreation parameters
    /// @return frameworkId identifier for framework, starting in 1
    function addLicenseFramework(
        Licensing.FrameworkCreationParams calldata fwCreation
    ) external returns (uint256 frameworkId) {
        // check protocol auth
        if (bytes(fwCreation.licenseUrl).length == 0 || fwCreation.licenseUrl.equal("")) {
            revert Errors.LicenseRegistry__EmptyLicenseUrl();
        }
        // Todo: check duplications

        ++_totalFrameworks;
        Licensing.Framework storage fw = _frameworks[_totalFrameworks];
        fw.licenseUrl = fwCreation.licenseUrl;
        _setParamArray(
            fw,
            Licensing.ParamVerifierType.Mint,
            fwCreation.mintingVerifiers,
            fwCreation.mintingDefaultValues
        );
        _setParamArray(
            fw,
            Licensing.ParamVerifierType.LinkParent,
            fwCreation.linkParentVerifiers,
            fwCreation.linkParentDefaultValues
        );
        _setParamArray(
            fw,
            Licensing.ParamVerifierType.Transfer,
            fwCreation.transferVerifiers,
            fwCreation.transferDefaultValues
        );
        emit LicenseFrameworkCreated(msg.sender, _totalFrameworks, fwCreation);
        return _totalFrameworks;
    }

    /// Convenience method to convert IParamVerifier[] + bytes[] into Parameter[]
    /// After conversion, it stores it in a Framework storage ref
    /// (Parameter[] can be in storage but not in calldata)
    /// @param fw storage ref to framework
    /// @param pvt ParamVerifierType, to know which parameters the arrays correspond to
    /// @param paramVerifiers verifier array contracts
    /// @param paramDefaultValues default values for the verifiers. Must be equal in length with paramVerifiers
    function _setParamArray(
        Licensing.Framework storage fw,
        Licensing.ParamVerifierType pvt,
        IParamVerifier[] calldata paramVerifiers,
        bytes[] calldata paramDefaultValues
    ) private {
        if (paramVerifiers.length != paramDefaultValues.length) {
            revert Errors.LicenseRegistry__ParamVerifierLengthMismatch();
        }
        // TODO: check pvt is valid
        Licensing.Parameter[] storage params = fw.parameters[pvt];
        for (uint256 i = 0; i < paramVerifiers.length; i++) {
            params.push(Licensing.Parameter({ verifier: paramVerifiers[i], defaultValue: paramDefaultValues[i] }));
        }
    }

    /// Gets total frameworks supported by LicenseRegistry
    function totalFrameworks() external view returns (uint256) {
        return _totalFrameworks;
    }

    /// Returns framework for id. Reverts if not found
    function frameworkParams(uint256 frameworkId, Licensing.ParamVerifierType pvt) public view returns (Licensing.Parameter[] memory) {
        Licensing.Framework storage fw = _framework(frameworkId);
        return fw.parameters[pvt];
    }

    function _framework(uint256 frameworkId) internal view returns (Licensing.Framework storage fw) {
        fw = _frameworks[frameworkId];
        if (bytes(fw.licenseUrl).length == 0) {
            revert Errors.LicenseRegistry__FrameworkNotFound();
        }
        return fw;
    }

    function frameworkUrl(uint256 frameworkId) external view returns (string memory) {
        return _framework(frameworkId).licenseUrl;
    }

    /// Stores data without repetition, assigning an id to it if new or reusing existing one if already stored
    /// @param data raw bytes, abi.encode() a value to be hashed
    /// @param _hashToIds storage ref to the mapping of hash -> data id
    /// @param existingIds amount of distinct data stored.
    /// @return id new sequential id if new data, reused id if not new
    /// @return isNew True if a new id was generated, signaling the value was stored in _hashToIds.
    ///               False if id is reused and data was not stored
    function _addIdOrGetExisting(
        bytes memory data,
        mapping(bytes32 => uint256) storage _hashToIds,
        uint256 existingIds
    ) private returns (uint256 id, bool isNew) {
        // We could just use the hash of the policy as id to save some gas, but the UX/DX of having huge random
        // numbers for ID is bad enough to justify the cost, plus we have accountability on current number of
        // policies.
        bytes32 hash = keccak256(data);
        id = _hashToIds[hash];
        if (id != 0) {
            return (id, false);
        }
        id = existingIds + 1;
        _hashToIds[hash] = id;
        return (id, true);
    }

    /// Adds a policy to an ipId, which can be used to mint licenses.
    /// Licenses are permissions for ipIds to be derivatives (children).
    /// If an exact policy already existed, it will reuse the id.
    /// Will revert if ipId already has the same policy
    /// @param ipId to receive the policy
    /// @param pol policy data
    /// @return policyId if policy data was in the contract, policyId is reused, if it's new, id will be new.
    /// @return isNew true if policy data was not in the contract, false if it was already stored
    /// @return indexOnIpId position of policy within the ipIds policy set
    function addPolicyToIp(
        address ipId,
        Licensing.Policy memory pol
    ) public returns (uint256 policyId, bool isNew, uint256 indexOnIpId) {
        // check protocol auth
        (uint256 polId, bool newPolicy) = _addPolicy(pol);
        return (polId, newPolicy, _addPolictyIdToIp(ipId, polId, false));
    }

    /// Adds a policy to an ipId, which can be used to mint licenses.
    /// Licnses are permissions for ipIds to be derivatives (children).
    /// if policyId is not defined in LicenseRegistry, reverts.
    /// Will revert if ipId already has the same policy
    /// @param ipId to receive the policy
    /// @param polId id of the policy data
    /// @return indexOnIpId position of policy within the ipIds policy set
    function addPolicyToIp(address ipId, uint256 polId) external returns (uint256 indexOnIpId) {
        if (!isPolicyDefined(polId)) {
            revert Errors.LicenseRegistry__PolicyNotFound();
        }
        return _addPolictyIdToIp(ipId, polId, false);
    }

    function addPolicy(Licensing.Policy memory pol) public returns (uint256 policyId) {
        (uint256 polId, bool newPol) = _addPolicy(pol);
        if (!newPol) {
            revert Errors.LicenseRegistry__PolicyAlreadyAdded();
        }
        return polId;
    }

    function _addPolicy(Licensing.Policy memory pol) public returns (uint256 policyId, bool isNew) {
        // We ignore the return value, we just want to check if the framework exists
        _framework(pol.frameworkId);
        (uint256 polId, bool newPol) = _addIdOrGetExisting(abi.encode(pol), _hashedPolicies, _totalPolicies);
        if (newPol) {
            _totalPolicies = polId;
            _policies[polId] = pol;
            emit PolicyCreated(msg.sender, polId, pol);
        }
        return (polId, newPol);
    }

    /// Adds a policy id to the ipId policy set
    /// Will revert if policy set already has policyId
    /// @param ipId the IP identifier
    /// @param policyId id of the policy data
    /// @param setByLinking true if set in linkIpToParent, false otherwise
    /// @return index of the policy added to the set
    function _addPolictyIdToIp(address ipId, uint256 policyId, bool setByLinking) internal returns (uint256 index) {
        EnumerableSet.UintSet storage policySet = _policiesPerIpId[ipId];
        // TODO: check if policy is compatible with the others
        if (!policySet.add(policyId)) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        _policyPerIpIdSetByLinking[ipId].push(setByLinking);
        index = policySet.length() - 1;
        emit PolicyAddedToIpId(msg.sender, ipId, policyId, index, setByLinking);
        return index;
    }

    /// Returns amount of distinct licensing policies in LicenseRegistry
    function totalPolicies() external view returns (uint256) {
        return _totalPolicies;
    }

    /// Gets policy data for policyId, reverts if not found
    function policy(uint256 policyId) public view returns (Licensing.Policy memory pol) {
        pol = _policies[policyId];
        if (pol.frameworkId == 0) {
            revert Errors.LicenseRegistry__PolicyNotFound();
        }
        return pol;
    }

    /// Returns true if policyId is defined in LicenseRegistry, false otherwise.
    function isPolicyDefined(uint256 policyId) public view returns (bool) {
        return _policies[policyId].frameworkId != 0;
    }

    /// Gets the policy set for an IpId
    /// @dev potentially expensive operation, use with care
    function policyIdsForIp(address ipId) external view returns (uint256[] memory policyIds) {
        return _policiesPerIpId[ipId].values();
    }

    function totalPoliciesForIp(address ipId) external view returns (uint256) {
        return _policiesPerIpId[ipId].length();
    }

    function isPolicyIdSetForIp(address ipId, uint256 policyId) external view returns (bool) {
        return _policiesPerIpId[ipId].contains(policyId);
    }

    function policyIdForIpAtIndex(address ipId, uint256 index) external view returns (uint256 policyId) {
        return _policiesPerIpId[ipId].at(index);
    }

    function wasPolicyIdForIpAtIndexSetByLinking(address ipId, uint256 index) external view returns (bool) {
        return _policyPerIpIdSetByLinking[ipId][index];
    }

    function policyForIpAtIndex(address ipId, uint256 index) external view returns (Licensing.Policy memory) {
        return _policies[_policiesPerIpId[ipId].at(index)];
    }

    function isPolicyIdAtIndexSetByLinking(address ipId, uint256 index) external view returns (bool) {
        return _policyPerIpIdSetByLinking[ipId][index];
    }

    /// Mints license NFTs representing a policy granted by a set of ipIds (licensors). This NFT needs to be burned
    /// in order to link a derivative IP with its parents.
    /// If this is the first combination of policy and licensors, a new licenseId
    /// will be created (by incrementing prev totalLicenses).
    /// If not, the license is fungible and an id will be reused.
    /// The licensing terms that regulate creating new licenses will be verified to allow minting.
    /// Reverts if caller is not authorized by licensors.
    /// @param policyId id of the policy to be minted
    /// @param licensorIds array of IP Ids that are granting the license
    /// @param amount of licenses to be minted. License NFT is fungible for same policy and same licensors
    /// @param receiver of the License NFT(s).
    /// @return licenseId of the NFT(s).
    function mintLicense(
        uint256 policyId,
        address[] memory licensorIds,
        uint256 amount,
        address receiver
    ) external returns (uint256 licenseId) {
        uint256 licensorAmount = licensorIds.length;
        if (licensorAmount == 0) {
            revert Errors.LicenseRegistry__LicenseMustHaveLicensors();
        }
        for (uint256 i = 0; i < licensorAmount; i++) {
            address licensor = licensorIds[i];
            // TODO: check duplicates
            // TODO: check if licensors are valid IP Ids
            // TODO: check if licensors they have been tagged by disputer
            // TODO: check if licensor allowed sender to mint in their behalf
            if (licensor == address(0)) {
                revert Errors.LicenseRegistry__InvalidLicensor();
            }
            if (!_policiesPerIpId[licensor].contains(policyId)) {
                revert Errors.LicenseRegistry__LicensorDoesntHaveThisPolicy();
            }
        }
        Licensing.Policy memory pol = policy(policyId);
        _verifyParams(Licensing.ParamVerifierType.Mint, pol, receiver, amount);
        Licensing.License memory licenseData = Licensing.License({
            policyId: policyId,
            licensorIpIds: licensorIds
        });
        (uint256 lId, bool isNew) = _addIdOrGetExisting(abi.encode(licenseData), _hashedLicenses, _totalLicenses);
        licenseId = lId;
        if (isNew) {
            _totalLicenses = licenseId;
            _licenses[licenseId] = licenseData;
            emit LicenseMinted(msg.sender, receiver, licenseId, amount, licenseData);
        }
        _mint(receiver, licenseId, amount, "");
        return licenseId;
    }

    /// Returns true if holder has positive balance for licenseId
    function isLicensee(uint256 licenseId, address holder) external view returns (bool) {
        return balanceOf(holder, licenseId) > 0;
    }

    function policyIdForLicense(uint256 licenseId) external view returns (uint256) {
        return _licenses[licenseId].policyId;
    }

    function policyForLicense(uint256 licenseId) public view returns (Licensing.Policy memory) {
        return policy(_licenses[licenseId].policyId);
    }

    /// Relates an IP ID with its parents (licensors), by burning the License NFT the holder owns
    /// Licensing parameters related to linking IPAs must be verified in order to succeed, reverts otherwise.
    /// The child IP ID will have the policy that the license represent added to it's own, if it's compatible with
    /// existing child policies.
    /// The child IP ID will be linked to the parent (if it wasn't before).
    /// @param licenseId license NFT to be burned
    /// @param childIpId that will receive the policy defined by licenseId
    /// @param holder of the license NFT
    function linkIpToParent(
        uint256 licenseId,
        address childIpId,
        address holder
    ) external onlyLicensee(licenseId, holder) {
        
        // TODO: check if childIpId exists and is owned by holder
        Licensing.License memory licenseData = _licenses[licenseId];
        address[] memory parents = licenseData.licensorIpIds;
        for (uint256 i = 0; i < parents.length; i++) {
            // TODO: check licensor exist
            // TODO: check licensor not part of a branch tagged by disputer
        }

        Licensing.Policy memory pol = policy(licenseData.policyId);
        _verifyParams(Licensing.ParamVerifierType.LinkParent, pol, holder, 1);
        
        // Add policy to kid
        // TODO: return index of policy in ipId?
        _addPolictyIdToIp(childIpId, licenseData.policyId, true);
        // Set parent
        for (uint256 i = 0; i < parents.length; i++) {
            // We don't care if it was already a parent, because there might be a case such as:
            // 1. IP2 is created from IP1 with L1(non commercial)
            // 2. IP1 releases L2 with commercial terms, and IP2 wants permission to commercially exploit
            // 3. IP2 gets L2, burns it to set commercial policy
            address parent = parents[i];
            if (parent == childIpId) {
                revert Errors.LicenseRegistry__ParentIdEqualThanChild();
            }
            _ipIdParents[childIpId].add(parent);
            emit IpIdLinkedToParent(msg.sender, childIpId, parent);
        }

        // Burn license
        _burn(holder, licenseId, 1);
    }

    /// Returns true if the child is derivative from the parent, by at least 1 policy.
    function isParent(address parentIpId, address childIpId) external view returns (bool) {
        return _ipIdParents[childIpId].contains(parentIpId);
    }

    function parentIpIds(address ipId) external view returns (address[] memory) {
        return _ipIdParents[ipId].values();
    }

    function totalParentsForIpId(address ipId) external view returns (uint256) {
        return _ipIdParents[ipId].length();
    }

    function license(uint256 licenseId) external view returns (Licensing.License memory) {
        return _licenses[licenseId];
    }

    function licensorIpIds(uint256 licenseId) external view returns (address[] memory) {
        return _licenses[licenseId].licensorIpIds;
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) virtual override internal {
        // We are interested in transfers, minting and burning are checked in mintLicense and linkIpToParent respectively.
        if (from != address(0) && to != address(0)) {
            uint256 length = ids.length;
            for (uint256 i = 0; i < length; i++) {
                _verifyParams(Licensing.ParamVerifierType.Transfer, policyForLicense(ids[i]), to, values[i]);
            }   
        }
        super._update(from, to, ids, values);
    }

    function _verifyLinkParams(uint256 licenseId, address holder, address childIpId, address parentIpId, bytes memory data) {
        
    }

    function _verifyParams(Licensing.ParamVerifierType pvt, Licensing.Policy memory pol, address holder, uint256 amount) internal {
        Licensing.Framework storage fw = _framework(pol.frameworkId);
        Licensing.Parameter[] storage params = fw.parameters[pvt];
        uint256 paramsLength = params.length;
        bytes[] memory values = pol.getValues(pvt);
        
        for (uint256 i = 0; i < paramsLength; i++) {
            Licensing.Parameter memory param = params[i];
            // Empty bytes => use default value specified in license framework creation params.
            bytes memory data = values[i].length == 0 ? param.defaultValue : values[i];
            bool verificationOk = false;
            if (pvt == Licensing.ParamVerifierType.Mint) {
                verificationOk = param.verifier.function verifyMint(
                    address caller,
                    uint256 policyId,
                    bool policyAddedByLinking,
                    address[] memory licensors,
                    address receiver,
                    uint256 amount,
                    bytes memory data
                ) external view returns (bool) 
            } else if (pvt == Licensing.ParamVerifierType.LinkParent) {
                verificationOk = param.verifier.verifyLink(
                    address licenseId,
                    address licenseHolder,
                    address ipId,
                    address parentIpId,
                    bytes calldata data
                )
            } else if (pvt == Licensing.ParamVerifierType.Transfer) {
                verificationOk = param.verifier.verifyTransfer(
                    uint256 licenseId,
                    address from,
                    address to,
                    uint256 amount,
                    bytes memory data
                );
            } else {
                // This should never happen since getValues checks for pvt validity
                revert Errors.LicenseRegistry__InvalidParamVerifierType();
            }
            if (!verificationOk) {
                revert Errors.LicenseRegistry__ParamVerifierFailed(uint8(pvt), address(param.verifier));
            }
        }
    }


    // TODO: tokenUri from parameters, from a metadata resolver contract
}
