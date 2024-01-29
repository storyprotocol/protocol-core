// // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

// contracts

import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { BaseLicensingFramework } from "contracts/modules/licensing/BaseLicensingFramework.sol";
import { LicensorApprovalManager } from "contracts/modules/licensing/parameters/LicensorApprovalManager.sol";

// external
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract LicensingFrameworkUML is
    BaseLicensingFramework,
    ILinkParamVerifier,
    IMintParamVerifier,
    ITransferParamVerifier,
    LicensorApprovalManager
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
    
    event UMLv1PolicyAdded(uint256 indexed policyId, UMLv1Policy policy);

    constructor(address licRegistry, string memory licenseUrl) BaseLicensingFramework(licRegistry, licenseUrl) {}

    function licenseRegistry() view override external returns (address) {
        return address(LICENSE_REGISTRY);
    }
    
    function addPolicy(UMLv1Policy calldata umlPolicy) external returns(uint256 policyId) {
        if (frameworkId == 0) {
            revert Errors.LicensingFrameworkUML_FrameworkNotYetRegistered();
        }
        _verifyComercialUse(umlPolicy);
        _verifyDerivatives(umlPolicy);
        Licensing.Policy memory protocolPolicy = Licensing.Policy({
            frameworkId: frameworkId,
            data: abi.encode(umlPolicy)
        });
        LICENSE_REGISTRY.addPolicy(protocolPolicy);
        emit UMLv1PolicyAdded(policyId, umlPolicy);
    }

    function policyToUmlPolicy(uint256 policyId) public view returns (UMLv1Policy memory policy) {
        Licensing.Policy memory protocolPolicy = LICENSE_REGISTRY.policy(policyId);
        if(protocolPolicy.frameworkId != frameworkId) {
            revert Errors.LicenseRegistry__FrameworkNotFound();
        }
        policy = abi.decode(protocolPolicy.data, (UMLv1Policy));
    }

    function policyToJson(bytes memory) public view returns (string memory) {
        return "TODO";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseLicensingFramework, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId) ||
            interfaceId == type(ILinkParamVerifier).interfaceId ||
            interfaceId == type(IMintParamVerifier).interfaceId ||
            interfaceId == type(ITransferParamVerifier).interfaceId;
    }

    function verifyLink(
        uint256 licenseId,
        address,
        address ipId,
        address,
        bytes calldata policyData
    )
        external override 
        onlyLicenseRegistry
        returns (bool) {
        UMLv1Policy memory policy = abi.decode(policyData, (UMLv1Policy));
        bool linkingOK = true;
        if (policy.commercialRevShare > 0) {
            // RoyaltyModule.setRevShare()
        }
        if (policy.derivativesRevShare > 0) {
            // RoyaltyModule.setRevShareForDerivatives()
        }
        if (policy.derivativesApproval) {
            linkingOK = linkingOK && isDerivativeApproved(licenseId, ipId);
        }
        return linkingOK;
    }

    function verifyMint(
        address,
        bool policyAddedByLinking,
        address,
        address,
        uint256,
        bytes memory policyData
    ) external returns (bool) {
        UMLv1Policy memory policy = abi.decode(policyData, (UMLv1Policy));
        if (!policy.derivativesAllowed && policyAddedByLinking) {
            // Parent said no derivatives, but child is trying to mint
            return false;
        }
        return true;
    }

    function verifyTransfer(
        uint256,
        address,
        address,
        uint256,
        bytes memory
    ) external returns (bool) {
        return true;
    }

    function _verifyComercialUse(UMLv1Policy calldata policy) internal pure {
        if (!policy.commercialUse) {
            if (policy.commercialAttribution) {
                revert Errors.LicensingFrameworkUML_CommecialDisabled_CantAddAttribution();
            }
            if (policy.commercializers.length > 0) {
                revert Errors.LicensingFrameworkUML_CommecialDisabled_CantAddCommercializers();
            }
            if (policy.commercialRevShare > 0) {
                revert Errors.LicensingFrameworkUML_CommecialDisabled_CantAddRevShare();
            }
            if (policy.derivativesRevShare > 0) {
                revert Errors.LicensingFrameworkUML_CommecialDisabled_CantAddDerivRevShare();
            }
        }
    }

    function _verifyDerivatives(UMLv1Policy calldata policy) internal pure {
        if (!policy.derivativesAllowed) {
            if (policy.derivativesAttribution) {
                revert Errors.LicensingFrameworkUML_DerivativesDisabled_CantAddAttribution();
            }
            if (policy.derivativesApproval) {
                revert Errors.LicensingFrameworkUML_DerivativesDisabled_CantAddApproval();
            }
            if (policy.derivativesReciprocal) {
                revert Errors.LicensingFrameworkUML_DerivativesDisabled_CantAddReciprocal();
            }
            if (policy.derivativesRevShare > 0) {
                revert Errors.LicensingFrameworkUML_DerivativesDisabled_CantAddRevShare();
            }
        }
    }


    
}



