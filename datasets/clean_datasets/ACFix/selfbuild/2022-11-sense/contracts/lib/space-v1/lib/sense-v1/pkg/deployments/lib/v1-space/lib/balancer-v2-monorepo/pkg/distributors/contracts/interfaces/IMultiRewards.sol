pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20.sol";
interface IMultiRewards {
    function notifyRewardAmount(
        IERC20 stakingToken,
        IERC20 rewardsToken,
        uint256 reward,
        address rewarder
    ) external;
    function addReward(
        IERC20 pool,
        IERC20 rewardsToken,
        uint256 rewardsDuration
    ) external;
    function allowlistRewarder(
        IERC20 pool,
        IERC20 rewardsToken,
        address rewarder
    ) external;
    function isAllowlistedRewarder(
        IERC20 pool,
        IERC20 rewardsToken,
        address rewarder
    ) external view returns (bool);
}