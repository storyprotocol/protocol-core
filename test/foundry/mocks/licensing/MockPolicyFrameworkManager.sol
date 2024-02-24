// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// contracts
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { Licensing } from "contracts/lib/Licensing.sol";

struct MockPolicyFrameworkConfig {
    address licensingModule;
    string name;
    string licenseUrl;
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
        Licensing.Policy memory pol = Licensing.Policy({
            isLicenseTransferable: true,
            policyFramework: address(this),
            frameworkData: "",
            royaltyPolicy: royaltyPolicy,
            royaltyData: abi.encode(mockPolicy),
            mintingFee: 0,
            mintingFeeToken: address(0)
        });
        return LICENSING_MODULE.registerPolicy(pol);
    }

    function verifyMint(address, bool, address, address, uint256, bytes memory data) external pure returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyMint;
    }

    function verifyLink(uint256, address, address, address, bytes calldata data) external pure override returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyLink;
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
}
