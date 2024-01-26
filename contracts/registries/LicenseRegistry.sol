// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

// contracts
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";


// TODO: consider disabling operators/approvals on creation
contract LicenseRegistry is ERC1155, ILicenseRegistry {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for *;
    using ShortStrings for *;
    using Licensing for *;

    struct PolicySetup {
        uint256 index;
        bool isSet;
        bool active;
        bool setByLinking;
    }

    mapping(uint256 => Licensing.Framework) private _frameworks;
    uint256 private _totalFrameworks;

    mapping(bytes32 => uint256) private _hashedPolicies;
    mapping(uint256 => Licensing.Policy) private _policies;
    uint256 private _totalPolicies;
    /// @notice internal mapping to track if a policy was set by linking or minting, and the
    /// index of the policy in the ipId policy set
    /// Policies can't be removed, but they can be deactivated by setting active to false
    /// @dev ipId => policyId => PolicySetup
    mapping(address => mapping(uint256 => PolicySetup)) private _policySetups;
    mapping(address => EnumerableSet.UintSet) private _policiesPerIpId;
    
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
        uint256 paramLength = fwCreation.parameters.length;
        if (paramLength != fwCreation.defaultValues.length) {
            revert Errors.LicenseRegistry__ParamVerifierLengthMismatch();
        }
        mapping(bytes32 => Licensing.Parameter) storage params = fw.parameters;
        for (uint256 i = 0; i < paramLength; i++) {
            IParamVerifier verifier = fwCreation.parameters[i];
            bytes32 paramName = verifier.name();
            if (address(params[paramName].verifier) != address(0)) {
                revert Errors.LicenseRegistry__ParamVerifierAlreadySet();
            }
            params[paramName] = Licensing.Parameter({ verifier: verifier, defaultValue: fwCreation.defaultValues[i] });
        }
       
        emit LicenseFrameworkCreated(msg.sender, _totalFrameworks, fwCreation);
        return _totalFrameworks;
    }


    /// Gets total frameworks supported by LicenseRegistry
    function totalFrameworks() external view returns (uint256) {
        return _totalFrameworks;
    }

    /// Returns framework for id. Reverts if not found
    function frameworkParam(uint256 frameworkId, string calldata name) public view returns (Licensing.Parameter memory) {
        Licensing.Framework storage fw = _framework(frameworkId);
        return fw.parameters[ShortString.unwrap(name.toShortString())];
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
        EnumerableSet.UintSet storage _pols = _policiesPerIpId[ipId];
        if (!_pols.add(policyId)) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        index = _pols.length() - 1;
        PolicySetup storage setup = _policySetups[ipId][policyId];
        // This should not happen, but just in case
        if (setup.isSet) {
            revert Errors.LicenseRegistry__PolicyAlreadySetForIpId();
        }
        setup.index = index;
        setup.isSet = true;
        setup.active = true;
        setup.setByLinking = setByLinking;
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

    function policyForIpAtIndex(address ipId, uint256 index) external view returns (Licensing.Policy memory) {
        return _policies[_policiesPerIpId[ipId].at(index)];
    }

    function indexOfPolicyForIp(address ipId, uint256 policyId) external view returns (uint256 index) {
        return _policySetups[ipId][policyId].index;
    }

    function isPolicySetByLinking(address ipId, uint256 policyId) external view returns (bool) {
        return _policySetups[ipId][policyId].setByLinking;
    }

    /// Mints license NFTs representing a policy granted by a set of ipIds (licensors). This NFT needs to be burned
    /// in order to link a derivative IP with its parents.
    /// If this is the first combination of policy and licensors, a new licenseId
    /// will be created (by incrementing prev totalLicenses).
    /// If not, the license is fungible and an id will be reused.
    /// The licensing terms that regulate creating new licenses will be verified to allow minting.
    /// Reverts if caller is not authorized by licensors.
    /// @param policyId id of the policy to be minted
    /// @param licensorIp IP Id granting the license
    /// @param amount of licenses to be minted. License NFT is fungible for same policy and same licensors
    /// @param receiver of the License NFT(s).
    /// @return licenseId of the NFT(s).
    function mintLicense(
        uint256 policyId,
        address licensorIp,
        uint256 amount,
        address receiver
    ) external returns (uint256 licenseId) {
        // TODO: check if licensor are valid IP Ids
        // TODO: check if licensor has been tagged by disputer
        // TODO: check if licensor allowed sender to mint in their behalf
        // TODO: licensor == msg.sender, expect if derivatives && withReciprocal
        if (licensorIp == address(0)) {
            revert Errors.LicenseRegistry__InvalidLicensor();
        }
        if (!_policiesPerIpId[licensorIp].contains(policyId)) {
            revert Errors.LicenseRegistry__LicensorDoesntHaveThisPolicy();
        }
        // Verify minting param
        Licensing.Policy memory pol = policy(policyId);
        Licensing.Framework storage fw = _framework(pol.frameworkId);
        uint256 policyParamsLength = pol.paramNames.length;
        bool setByLinking = _policySetups[licensorIp][policyId].setByLinking;
        bool verificationOk = true;
        for (uint256 i = 0; i < policyParamsLength; i++) {
            Licensing.Parameter memory param = fw.parameters[pol.paramNames[i]];

            if (ERC165Checker.supportsInterface(address(param.verifier), type(IMintParamVerifier).interfaceId)) {
                bytes memory data = pol.paramValues[i].length == 0 ? param.defaultValue : pol.paramValues[i];
                verificationOk = IMintParamVerifier(address(param.verifier)).verifyMint(
                    msg.sender,
                    policyId,
                    setByLinking,
                    licensorIp,
                    receiver,
                    data
                );
            }
        }
        
        Licensing.License memory licenseData = Licensing.License({
            policyId: policyId,
            licensorIpId: licensorIp
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
        address parentIpId = licenseData.licensorIpId;
        if (parentIpId == childIpId) {
            revert Errors.LicenseRegistry__ParentIdEqualThanChild();
        }
        // TODO: check licensor exist
        // TODO: check licensor not part of a branch tagged by disputer

        // Verify linking params
        Licensing.Policy memory pol = policy(licenseData.policyId);
        Licensing.Framework storage fw = _framework(pol.frameworkId);
        uint256 policyParamsLength = pol.paramNames.length;
        bool verificationOk = true;
        for (uint256 i = 0; i < policyParamsLength; i++) {
            Licensing.Parameter memory param = fw.parameters[pol.paramNames[i]];

            if (ERC165Checker.supportsInterface(address(param.verifier), type(ILinkParamVerifier).interfaceId)) {
                bytes memory data = pol.paramValues[i].length == 0 ? param.defaultValue : pol.paramValues[i];
                verificationOk = ILinkParamVerifier(address(param.verifier)).verifyLink(
                    licenseId,
                    msg.sender,
                    childIpId,
                    parentIpId,
                    data
                );
            }
        }
        
        // Add policy to kid
        _addPolictyIdToIp(childIpId, licenseData.policyId, true);
        // Set parent
        _ipIdParents[childIpId].add(parentIpId);
        emit IpIdLinkedToParent(msg.sender, childIpId, parentIpId);

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

    function licensorIpId(uint256 licenseId) external view returns (address) {
        return _licenses[licenseId].licensorIpId;
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) virtual override internal {
        // We are interested in transfers, minting and burning are checked in mintLicense and linkIpToParent respectively.
        if (from != address(0) && to != address(0)) {
            uint256 length = ids.length;
            for (uint256 i = 0; i < length; i++) {
                // Verify transfer params
                uint256 licenseId = ids[i];
                Licensing.Policy memory pol = policy(_licenses[licenseId].policyId);
                Licensing.Framework storage fw = _framework(pol.frameworkId);
                uint256 policyParamsLength = pol.paramNames.length;
                bool verificationOk = true;
                for (uint256 j = 0; j < policyParamsLength; j++) {
                    Licensing.Parameter memory param = fw.parameters[pol.paramNames[j]];
                    bytes memory paramValue = pol.paramValues[j];
                    if (ERC165Checker.supportsInterface(address(param.verifier), type(ITransferParamVerifier).interfaceId)) {
                        bytes memory data = paramValue.length == 0 ? param.defaultValue : paramValue;
                        verificationOk = ITransferParamVerifier(address(param.verifier)).verifyTransfer(
                            licenseId,
                            from,
                            to,
                            values[i],
                            data
                        );
                    }
                }
            }   
        }
        super._update(from, to, ids, values);
    }


    // TODO: tokenUri from parameters, from a metadata resolver contract
}
