// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// contracts
import { Governable } from "contracts/governance/Governable.sol";
import { IDisputeModule } from "contracts/interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "contracts/interfaces/modules/dispute/policies/IArbitrationPolicy.sol";
import { Errors } from "contracts/lib/Errors.sol";

/// @title Story Protocol Arbitration Policy
/// @notice The Story Protocol arbitration policy is a simple policy that
///         requires the dispute initiator to pay a fixed amount of tokens
///         to raise a dispute and refunds that amount if the dispute initiator
///         wins the dispute.
contract ArbitrationPolicySP is IArbitrationPolicy, Governable {
    using SafeERC20 for IERC20;

    /// @notice Dispute module address
    address public immutable DISPUTE_MODULE;

    /// @notice Payment token address
    address public immutable PAYMENT_TOKEN;

    /// @notice Arbitration price
    uint256 public immutable ARBITRATION_PRICE;

    /// @notice Restricts the calls to the dispute module
    modifier onlyDisputeModule() {
        if (msg.sender != DISPUTE_MODULE) revert Errors.ArbitrationPolicySP__NotDisputeModule();
        _;
    }

    /// @notice Constructor
    /// @param _disputeModule Address of the dispute module contract
    /// @param _paymentToken Address of the payment token
    /// @param _arbitrationPrice Arbitration price
    /// @param _governable Address of the governable contract
    constructor(address _disputeModule, address _paymentToken, uint256 _arbitrationPrice, address _governable) Governable(_governable) {
        if (_disputeModule == address(0)) revert Errors.ArbitrationPolicySP__ZeroDisputeModule();
        if (_paymentToken == address(0)) revert Errors.ArbitrationPolicySP__ZeroPaymentToken();

        DISPUTE_MODULE = _disputeModule;
        PAYMENT_TOKEN = _paymentToken;
        ARBITRATION_PRICE = _arbitrationPrice;
    }

    /// @notice Executes custom logic on raise dispute
    /// @param _caller Address of the caller
    function onRaiseDispute(address _caller, bytes calldata) external onlyDisputeModule {
        // requires that the caller has given approve() to this contract
        IERC20(PAYMENT_TOKEN).safeTransferFrom(_caller, address(this), ARBITRATION_PRICE);
    }

    /// @notice Executes custom logic on dispute judgement
    /// @param _disputeId The dispute id
    /// @param _decision The decision of the dispute
    function onDisputeJudgement(uint256 _disputeId, bool _decision, bytes calldata) external onlyDisputeModule {
        if (_decision) {
            (, address disputeInitiator,,,,) = IDisputeModule(DISPUTE_MODULE).disputes(_disputeId);
            IERC20(PAYMENT_TOKEN).safeTransfer(disputeInitiator, ARBITRATION_PRICE);
        }
    }

    /// @notice Executes custom logic on dispute cancel
    function onDisputeCancel(address, uint256, bytes calldata) external onlyDisputeModule {}

    /// @notice Allows governance address to withdraw
    function governanceWithdraw() external onlyProtocolAdmin {
        uint256 balance = IERC20(PAYMENT_TOKEN).balanceOf(address(this));
        IERC20(PAYMENT_TOKEN).safeTransfer(governance, balance);

        emit GovernanceWithdrew(balance);
    }
}
