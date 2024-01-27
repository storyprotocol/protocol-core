// // SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.23;

import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { BaseParamVerifier } from "contracts/modules/licensing/parameters/BaseParamVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract DerivWithApprovalPV is BaseParamVerifier, ILinkParamVerifier {

    event DerivativeApproved(uint256 indexed licenseId, address indexed ipId, address indexed caller, bool approved);

    // License Id => childIpId => approved
    mapping(uint256 => mapping(address => bool)) private _approvals;

    constructor(address licenseRegistry) BaseParamVerifier(licenseRegistry) {}

    // TODO: meta tx version
    function setApproval(uint256 licenseId, bool approved) external {
        address licensorIpId = LICENSE_REGISTRY.licensorIpId(licenseId);
        // TODO: ACL
        bool callerIsLicensor = true; // msg.sender is licensorIpId owner ;
        if (!callerIsLicensor) {
            revert Errors.DerivWithApprovalPV__Unauthorized();
        }
        _approvals[licenseId][licensorIpId] = approved;
        emit DerivativeApproved(licenseId, licensorIpId, msg.sender, approved);
    }

    function isDerivativeApproved(uint256 licenseId, address licensorIpId) public view returns (bool) {
        return _approvals[licenseId][licensorIpId];
    }

    function verifyLink(
        uint256 licenseId,
        address caller,
        address ipId,
        address parentIpId,
        bytes calldata data
    ) external view returns (bool) {
        return isDerivativeApproved(licenseId, parentIpId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return
            interfaceId == type(IParamVerifier).interfaceId ||
            interfaceId == type(ILinkParamVerifier).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function json() external pure virtual override(BaseParamVerifier, IParamVerifier) returns (string memory) {
        return "";
    }

    function name() public view virtual override(BaseParamVerifier, IParamVerifier) returns (bytes32) {
        return ShortStringOps.stringToBytes32("Derivatives-With-Approval");
    }

    function isCommercial() external pure override returns (bool) {
        return false;
    }

    function allowsOtherPolicyOnSameIp(bytes memory data) external pure override returns (bool) {
        return true;
    }
}



