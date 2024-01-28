// // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";


contract LicensingModuleUML is
    BaseLicensingModule,
    IParamVerifier,
    ILinkParamVerifier,
    IMintParamVerifier,
    ITransferParamVerifier,
    IPApprovalManager
    {

    struct UMLv1Policy {
        bool attribution;
        bool commercialUse;
        bool commercialAttribution;
        string[] commercializers;
        uint256 commercialRevShare;
        bool derivativesAllowed;
        bool derivativesAttribution;
        bool derivativesApproval;
        bool derivativesReciprocal;
        uint256 derivativesRevShare;
        string[] territories;
        string[] distributionChannels;
    }
    
    emit UMLv1PolicyAdded(uint256 indexed policyId, UMLv1Policy policy);

    constructor(LicenseRegistry licenseRegistry, uint256 frameworkId) {
        _REGISTRY = licenseRegistry;
        FRAMEWORK_ID = frameworkId;
    }

    function licenseRegistry() external view returns (address) {
        return address(_REGISTRY);
    }
    
    function addPolicy(UMLv1Policy calldata policy) external returns(policyId) {
        _verifyComercialUse(policy);
        _verifyDerivatives(policy);
        Licensing.Policy memory protocolPolicy = Licensing.Policy({
            frameworkId: FRAMEWORK_ID,
            data: abi.encode(policy)
        })
        _REGISTRY.addPolicy(protocolPolicy);
        emit UMLv1PolicyAdded(policyId, policy);
    }

    function policy(uint256 policyId) public view returns (UMLv1Policy memory policy) {
        Licensing.Policy memory protocolPolicy = _REGISTRY.getPolicy(policyId);
        if(protocolPolicy.frameworkId != FRAMEWORK_ID) {
            Errors.LicenseRegistry__FrameworkNotFound();
        }
        policy = abi.decode(protocolPolicy.data, (UMLv1Policy));
    }

    function policyToJson(uint256 policyId) public view returns (string memory) {
        // get policy and covert to JSON for metadata
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IParamVerifier).interfaceId
            || interfaceId == type(ILinkParamVerifier).interfaceId
            || interfaceId == type(IMintParamVerifier).interfaceId
            || interfaceId == type(ITransferParamVerifier).interfaceId
            || interfaceId == type(ILicensingModule).interfaceId;
    }

    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata policyData
    ) external returns (bool) {
        UMLv1Policy memory policy = abi.decode(policyData, (UMLv1Policy));
        bool linkingOK = true;
        if (policy.commercialRevShare) {
            // RoyaltyModule.setRevShare()
        }
        if (policy.derivativesRevShare) {
            // RoyaltyModule.setRevShareForDerivatives()
        }
        if (policy.derivativesApproval) {
            linkingOK = linkingOK && isDerivativeApproved(licenseId, ipId);
        }
        return linkingOK;
    }

    function verifyMint(
        address caller,
        bool policyAddedByLinking,
        bytes memory policyData,
        address licensors,
        address receiver,
        uint256 mintAmount,
    ) external returns (bool) {
        UMLv1Policy memory policy = abi.decode(policyData, (UMLv1Policy));
        if (!policy.derivativesAllowed && policyAddedByLinking) {
            // Parent said no derivatives, but child is trying to mint
            return false;
        }
        return true;
    }


    function _verifyComercialUse(UMLv1Policy calldata policy) internal pure {
        if (!policy.commercialUse) {
            if (policy.commercialAttribution) {
                revert Errors.LicensingModuleUML_CommecialDisabled_CantAddAttribution();
            }
            if (policy.commercializers.length > 0) {
                revert Errors.LicensingModuleUML_CommecialDisabled_CantAddCommercializers();
            }
            if (policy.commercialRevShare > 0) {
                revert Errors.LicensingModuleUML_CommecialDisabled_CantAddRevShare();
            }
            if (policy.derivativesRevShare > 0) {
                revert Errors.LicensingModuleUML_CommecialDisabled_CantAddDerivRevShare();
            }
        }
    }

    function _verifyDerivatives(UMLv1Policy calldata policy) internal pure {
        if (!policy.derivativesAllowed) {
            if (policy.derivativesAttribution) {
                revert Errors.LicensingModuleUML_DerivativesDisabled_CantAddAttribution();
            }
            if (policy.derivativesApproval) {
                revert Errors.LicensingModuleUML_DerivativesDisabled_CantAddApproval();
            }
            if (policy.derivativesReciprocal) {
                revert Errors.LicensingModuleUML_DerivativesDisabled_CantAddReciprocal();
            }
            if (policy.derivativesRevShare > 0) {
                revert Errors.LicensingModuleUML_DerivativesDisabled_CantAddRevShare();
            }
        }
    }


    
}



