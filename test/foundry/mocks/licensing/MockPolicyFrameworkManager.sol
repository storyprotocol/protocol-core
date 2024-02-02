// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// contracts
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { IPolicyVerifier } from "contracts/interfaces/licensing/IPolicyVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

struct MockPolicyFrameworkConfig {
    address licenseRegistry;
    string name;
    string licenseUrl;
    bool supportVerifyLink;
    bool supportVerifyMint;
    bool supportVerifyTransfer;
}

struct MockPolicy {
    bool returnVerifyLink;
    bool returnVerifyMint;
    bool returnVerifyTransfer;
}

contract MockPolicyFrameworkManager is
    BasePolicyFrameworkManager,
    ILinkParamVerifier,
    IMintParamVerifier,
    ITransferParamVerifier
{
    MockPolicyFrameworkConfig internal config;

    event MockPolicyAdded(uint256 indexed policyId, MockPolicy policy);

    constructor(
        MockPolicyFrameworkConfig memory conf
    ) BasePolicyFrameworkManager(conf.licenseRegistry, conf.name, conf.licenseUrl) {
        config = conf;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, BasePolicyFrameworkManager) returns (bool) {
        if (interfaceId == type(IPolicyVerifier).interfaceId) return true;
        if (interfaceId == type(ILinkParamVerifier).interfaceId) return config.supportVerifyLink;
        if (interfaceId == type(IMintParamVerifier).interfaceId) return config.supportVerifyMint;
        if (interfaceId == type(ITransferParamVerifier).interfaceId) return config.supportVerifyTransfer;
        return super.supportsInterface(interfaceId);
    }

    function registerPolicy(MockPolicy calldata mockPolicy) external returns (uint256 policyId) {
        emit MockPolicyAdded(policyId, mockPolicy);
        return LICENSE_REGISTRY.registerPolicy(abi.encode(mockPolicy));
    }

    function verifyMint(address, bool, address, address, uint256, bytes memory data) external pure returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyMint;
    }

    function verifyLink(
        uint256,
        address,
        address,
        address,
        bytes calldata data
    ) external pure override returns (ILinkParamVerifier.VerifyLinkResponse memory) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return
            ILinkParamVerifier.VerifyLinkResponse({
                isLinkingAllowed: policy.returnVerifyLink,
                isRoyaltyRequired: false,
                royaltyPolicy: address(0),
                royaltyDerivativeRevShare: 0
            });
    }

    function verifyTransfer(
        uint256,
        address,
        address,
        uint256,
        bytes memory data
    ) external pure override returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyTransfer;
    }

    function policyToJson(bytes memory policyData) public pure returns (string memory) {
        return "MockPolicyFrameworkManager";
    }
    
    function processInheritedPolicies(
        bytes memory ipRights,
        bytes memory policy
    ) external pure override returns (bool changedRights, bytes memory newRights) {
        return (false, ipRights);
    }
}
