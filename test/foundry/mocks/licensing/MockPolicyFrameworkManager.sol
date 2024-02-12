// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// contracts
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { IPolicyFrameworkManager } from "contracts/interfaces/modules/licensing/IPolicyFrameworkManager.sol";

struct MockPolicyFrameworkConfig {
    address licensingModule;
    string name;
    string licenseUrl;
    bool supportVerifyLink;
    bool supportVerifyMint;
    address royaltyPolicy;
}

struct MockPolicy {
    bool returnVerifyLink;
    bool returnVerifyMint;
}

contract MockPolicyFrameworkManager is BasePolicyFrameworkManager {
    MockPolicyFrameworkConfig internal config;

    address internal royaltyPolicy;

    event MockPolicyAdded(uint256 indexed policyId, MockPolicy policy);

    constructor(
        MockPolicyFrameworkConfig memory conf
    ) BasePolicyFrameworkManager(conf.licensingModule, conf.name, conf.licenseUrl) {
        config = conf;
        royaltyPolicy = conf.royaltyPolicy;
    }

    function registerPolicy(MockPolicy calldata mockPolicy) external returns (uint256 policyId) {
        emit MockPolicyAdded(policyId, mockPolicy);
        return LICENSING_MODULE.registerPolicy(true, abi.encode(mockPolicy));
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
    ) external pure override returns (IPolicyFrameworkManager.VerifyLinkResponse memory) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return
            IPolicyFrameworkManager.VerifyLinkResponse({
                isLinkingAllowed: policy.returnVerifyLink,
                isRoyaltyRequired: false,
                royaltyPolicy: address(0),
                royaltyDerivativeRevShare: 0
            });
    }

    function policyToJson(bytes memory) public pure returns (string memory) {
        return "MockPolicyFrameworkManager";
    }

    function processInheritedPolicies(
        bytes memory aggregator,
        uint256, // policyId,
        bytes memory // policy
    ) external pure override returns (bool changedAgg, bytes memory newAggregator) {
        return (false, aggregator);
    }

    function getRoyaltyPolicy(uint256) public view override returns (address) {
        return address(royaltyPolicy);
    }

    function getCommercialRevenueShare(uint256) public pure override returns (uint32) {
        return 0;
    }

    function isPolicyCommercial(uint256 policyId) external pure returns (bool) {
        return policyId % 2 == 0;
    }
}
