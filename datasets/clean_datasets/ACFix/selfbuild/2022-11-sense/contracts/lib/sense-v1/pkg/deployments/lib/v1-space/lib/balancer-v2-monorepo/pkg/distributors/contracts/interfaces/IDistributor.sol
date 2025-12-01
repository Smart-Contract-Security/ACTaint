pragma solidity ^0.7.0;
interface IDistributor {
    event RewardAdded(address indexed token, uint256 amount);
    event RewardPaid(address indexed user, address indexed rewardToken, uint256 amount);
}