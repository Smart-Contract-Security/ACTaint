pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
interface IAssetManager {
    event Rebalance(bytes32 poolId);
    function setConfig(bytes32 poolId, bytes calldata config) external;
    function getToken() external view returns (IERC20);
    function getAUM(bytes32 poolId) external view returns (uint256);
    function getPoolBalances(bytes32 poolId) external view returns (uint256 poolCash, uint256 poolManaged);
    function maxInvestableBalance(bytes32 poolId) external view returns (int256);
    function updateBalanceOfPool(bytes32 poolId) external;
    function shouldRebalance(uint256 cash, uint256 managed) external view returns (bool);
    function rebalance(bytes32 poolId, bool force) external;
    function capitalOut(bytes32 poolId, uint256 amount) external;
}