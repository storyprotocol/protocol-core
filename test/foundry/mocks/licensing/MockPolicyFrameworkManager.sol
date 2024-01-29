// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// external
import { ERC165, IERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
// contracts
import { ILinkParamVerifier } from "contracts/interfaces/licensing/ILinkParamVerifier.sol";
import { IMintParamVerifier } from "contracts/interfaces/licensing/IMintParamVerifier.sol";
import { IParamVerifier } from "contracts/interfaces/licensing/IParamVerifier.sol";
import { ITransferParamVerifier } from "contracts/interfaces/licensing/ITransferParamVerifier.sol";
import { Errors } from "contracts/lib/Errors.sol";
import { Licensing } from "contracts/lib/Licensing.sol";
import { BasePolicyFrameworkManager } from "contracts/modules/licensing/BasePolicyFrameworkManager.sol";
import { ShortStringOps } from "contracts/utils/ShortStringOps.sol";

struct MockPolicyFrameworkConfig {
    address licenseRegistry;
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
    ) BasePolicyFrameworkManager(conf.licenseRegistry, conf.licenseUrl) {
        config = conf;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165, BasePolicyFrameworkManager) returns (bool) {
        if (interfaceId == type(IParamVerifier).interfaceId) return true;
        if (interfaceId == type(ILinkParamVerifier).interfaceId) return config.supportVerifyLink;
        if (interfaceId == type(IMintParamVerifier).interfaceId) return config.supportVerifyMint;
        if (interfaceId == type(ITransferParamVerifier).interfaceId) return config.supportVerifyTransfer;
        return super.supportsInterface(interfaceId);
    }

    function addPolicy(MockPolicy calldata mockPolicy) external returns (uint256 policyId) {
        if (frameworkId == 0) {
            revert Errors.UMLPolicyFrameworkManager_FrameworkNotYetRegistered();
        }

        // can verify mockPolicy if needed

        Licensing.Policy memory protocolPolicy = Licensing.Policy({
            frameworkId: frameworkId,
            data: abi.encode(mockPolicy)
        });

        return LICENSE_REGISTRY.addPolicy(protocolPolicy);
        emit MockPolicyAdded(policyId, mockPolicy);
    }

    function policyIdToMockPolicy(uint256 policyId) public view returns (MockPolicy memory policy) {
        Licensing.Policy memory protocolPolicy = LICENSE_REGISTRY.policy(policyId);
        if (protocolPolicy.frameworkId != frameworkId) {
            revert Errors.LicenseRegistry__FrameworkNotFound();
        }
        policy = abi.decode(protocolPolicy.data, (MockPolicy));
    }

    function verifyMint(address, bool, address, address, uint256, bytes memory data) external view returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyMint;
    }

    function verifyLink(uint256, address, address, address, bytes calldata data) external pure override returns (bool) {
        MockPolicy memory policy = abi.decode(data, (MockPolicy));
        return policy.returnVerifyLink;
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
}
