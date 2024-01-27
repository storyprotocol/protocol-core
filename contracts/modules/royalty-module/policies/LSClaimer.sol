// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import { ILicenseRegistry } from "contracts/interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "contracts/lib/Errors.sol";

contract LSClaimer is ERC1155Holder {
    // TODO: what happens if license registry address changes in the future | should it be immutable?
    ILicenseRegistry ILICENSE_REGISTRY;

    // TODO: what happens if ROYALTY_POLICY_LS address changes in the future | should it be immutable?
    address public immutable ROYALTY_POLICY_LS;
    
    address public immutable IP_ID;


    address public RNFT;

    mapping(bytes32 pathHash => bool) public claimedPaths;

    modifier onlyRoyaltyPolicyLS() {
        //if (msg.sender != ROYALTY_POLICY_LS) revert Errors.LSClaimer__NotRoyaltyPolicyLS();
        _;
    }

    constructor(address _royaltyPolicyLS, address _ipId, address _licenseRegistry) {
        // TODO check if _ipId cannot be 0 and must be valid/exist

        ROYALTY_POLICY_LS = _royaltyPolicyLS;
        IP_ID = _ipId;
        ILICENSE_REGISTRY = ILicenseRegistry(_licenseRegistry);
    }

    function setRNFT(address _rnft) external onlyRoyaltyPolicyLS {
        // TODO check if _rnft cannot be 0
        RNFT = _rnft;
    }

    function claim(address[] memory _path, address _claimerIpId) external {
        //if (claimedPaths[_path]) revert Errors.LSClaimer__AlreadyClaimed();
        // TODO: path position 0 is IP_ID
        // TODO: path last position is _claimerIpId

        for (uint256 i = 0; i < _path.length; i++) {
           if(!ILICENSE_REGISTRY.isParent(_path[i], _path[i+1])) revert Errors.LSClaimer__InvalidPath();
        }

        // TODO: can we use keccak256(_path) support an array with 1000 length?
        bytes32 pathHash = keccak256(abi.encodePacked(_path));
        claimedPaths[pathHash] = true;

        // RNFT transfer
    }

    // TODO
    function sendToSplitClone() external {}
}