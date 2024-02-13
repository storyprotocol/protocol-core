// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IRoyaltyModule } from "../../../../contracts/interfaces/modules/royalty/IRoyaltyModule.sol";
import { IRoyaltyPolicy } from "../../../../contracts/interfaces/modules/royalty/policies/IRoyaltyPolicy.sol";

contract MockRoyaltyModule is IRoyaltyModule {
    string public constant name = "MockRoyaltyModule";
    address public LICENSING_MODULE;
    mapping(address royaltyPolicy => bool allowed) public isWhitelistedRoyaltyPolicy;
    mapping(address token => bool) public isWhitelistedRoyaltyToken;
    mapping(address ipId => address royaltyPolicy) public royaltyPolicies;
    mapping(address ipId => bool) public isRoyaltyPolicyImmutable;

    constructor() {}

    function setLicensingModule(address _licensingModule) external {
        LICENSING_MODULE = _licensingModule;
    }

    function whitelistRoyaltyPolicy(address _royaltyPolicy, bool _allowed) external {
        isWhitelistedRoyaltyPolicy[_royaltyPolicy] = _allowed;
    }

    function whitelistRoyaltyToken(address _token, bool _allowed) external {
        isWhitelistedRoyaltyToken[_token] = _allowed;
    }

    function setRoyaltyPolicy(
        address _ipId,
        address _royaltyPolicy,
        address[] calldata _parentIpIds,
        bytes calldata _data
    ) external {
        if (_parentIpIds.length > 0) isRoyaltyPolicyImmutable[_ipId] = true;
        for (uint32 i = 0; i < _parentIpIds.length; i++) {
            isRoyaltyPolicyImmutable[_parentIpIds[i]] = true;
        }
        royaltyPolicies[_ipId] = _royaltyPolicy;
        IRoyaltyPolicy(_royaltyPolicy).initPolicy(_ipId, _parentIpIds, _data);
    }

    function setRoyaltyPolicyImmutable(address _ipId) external {
        isRoyaltyPolicyImmutable[_ipId] = true;
    }

    function payRoyaltyOnBehalf(address _receiverIpId, address, address _token, uint256 _amount) external {
        address royaltyPolicy = royaltyPolicies[_receiverIpId];
        IRoyaltyPolicy(royaltyPolicy).onRoyaltyPayment(msg.sender, _receiverIpId, _token, _amount);
    }

    function minRoyaltyFromDescendants(address _ipId) external view returns (uint256) {
        address royaltyPolicy = royaltyPolicies[_ipId];
        return IRoyaltyPolicy(royaltyPolicy).minRoyaltyFromDescendants(_ipId);
    }
}
