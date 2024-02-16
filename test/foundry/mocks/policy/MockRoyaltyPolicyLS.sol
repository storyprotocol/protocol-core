// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

// external
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
// contracts
import { IRoyaltyPolicyLS } from "contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLS.sol";
import { Errors } from "contracts/lib/Errors.sol";

contract MockRoyaltyPolicyLS is IRoyaltyPolicyLS, ERC1155Holder {
    address public ROYALTY_MODULE;
    address public LICENSING_MODULE = address(0x0);
    address public LIQUID_SPLIT_FACTORY = address(0x0);
    address public LIQUID_SPLIT_MAIN = address(0x0);
    uint32 public constant TOTAL_RNFT_SUPPLY = 1000;

    mapping(address ipId => LSRoyaltyData) public royaltyData;

    mapping(address ipId => uint32 minRoyalty) public minRoyalty;

    /// @notice Restricts the calls to the royalty module
    modifier onlyRoyaltyModule() {
        if (msg.sender != ROYALTY_MODULE) revert Errors.RoyaltyPolicyLS__NotRoyaltyModule();
        _;
    }

    /// @notice Constructor
    /// @param _royaltyModule Address of the RoyaltyModule contract
    constructor(address _royaltyModule) {
        ROYALTY_MODULE = _royaltyModule;
    }

    function initPolicy(address _ipId, address[] calldata, bytes calldata) external onlyRoyaltyModule {
        royaltyData[_ipId] = LSRoyaltyData({
            splitClone: address(0x1),
            claimer: address(0x2),
            royaltyStack: 100,
            minRoyalty: 50
        });
    }

    function onRoyaltyPayment(
        address _caller,
        address _ipId,
        address _token,
        uint256 _amount
    ) external onlyRoyaltyModule {}

    function minRoyaltyFromDescendants(address _ipId) external view returns (uint32) {
        return minRoyalty[_ipId];
    }

    function setMinRoyalty(address _ipId, uint32 _minRoyalty) external {
        minRoyalty[_ipId] = _minRoyalty;
    }

    function distributeFunds(
        address _ipId,
        address _token,
        address[] calldata _accounts,
        address _distributorAddress
    ) external {}

    function claimRoyalties(address _account, uint256 _withdrawETH, ERC20[] calldata _tokens) external pure {}

    function _checkRoyaltyStackIsValid(address[] calldata, uint32) internal pure returns (uint32, uint32) {
        return (0, 0);
    }

    function _deploySplitClone(address, address, uint32) internal pure returns (address) {
        return address(0xbeef);
    }
}
