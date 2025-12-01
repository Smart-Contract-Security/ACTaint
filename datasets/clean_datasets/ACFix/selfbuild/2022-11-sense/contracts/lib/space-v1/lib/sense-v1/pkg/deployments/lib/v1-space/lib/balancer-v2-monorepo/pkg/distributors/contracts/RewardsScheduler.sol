pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/SafeERC20.sol";
import "./interfaces/IMultiRewards.sol";
contract RewardsScheduler {
    using SafeERC20 for IERC20;
    IMultiRewards private immutable _multirewards;
    constructor() {
        _multirewards = IMultiRewards(msg.sender);
    }
    enum RewardStatus { UNINITIALIZED, PENDING, STARTED }
    struct ScheduledReward {
        IERC20 pool;
        IERC20 rewardsToken;
        uint256 startTime;
        address rewarder;
        uint256 amount;
        RewardStatus status;
    }
    event RewardScheduled(
        bytes32 rewardId,
        address indexed rewarder,
        IERC20 indexed pool,
        IERC20 indexed rewardsToken,
        uint256 startTime,
        uint256 amount
    );
    event RewardStarted(
        bytes32 rewardId,
        address indexed rewarder,
        IERC20 indexed pool,
        IERC20 indexed rewardsToken,
        uint256 startTime,
        uint256 amount
    );
    mapping(bytes32 => ScheduledReward) private _rewards;
    function getScheduledRewardInfo(bytes32 rewardId) external view returns (ScheduledReward memory reward) {
        return _rewards[rewardId];
    }
    function startRewards(bytes32[] calldata rewardIds) external {
        for (uint256 r; r < rewardIds.length; r++) {
            bytes32 rewardId = rewardIds[r];
            ScheduledReward memory scheduledReward = _rewards[rewardId];
            require(scheduledReward.status == RewardStatus.PENDING, "Reward cannot be started");
            require(scheduledReward.startTime <= block.timestamp, "Reward start time is in the future");
            _rewards[rewardId].status = RewardStatus.STARTED;
            if (
                scheduledReward.rewardsToken.allowance(address(this), address(_multirewards)) < scheduledReward.amount
            ) {
                scheduledReward.rewardsToken.approve(address(_multirewards), type(uint256).max);
            }
            _multirewards.notifyRewardAmount(
                scheduledReward.pool,
                scheduledReward.rewardsToken,
                scheduledReward.amount,
                scheduledReward.rewarder
            );
            emit RewardStarted(
                rewardId,
                scheduledReward.rewarder,
                scheduledReward.pool,
                scheduledReward.rewardsToken,
                scheduledReward.startTime,
                scheduledReward.amount
            );
        }
    }
    function getRewardId(
        IERC20 pool,
        IERC20 rewardsToken,
        address rewarder,
        uint256 startTime
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(pool, rewardsToken, rewarder, startTime));
    }
    function scheduleReward(
        IERC20 pool,
        IERC20 rewardsToken,
        uint256 amount,
        uint256 startTime
    ) public returns (bytes32 rewardId) {
        rewardId = getRewardId(pool, rewardsToken, msg.sender, startTime);
        require(startTime > block.timestamp, "Reward can only be scheduled for the future");
        require(
            _multirewards.isAllowlistedRewarder(pool, rewardsToken, msg.sender),
            "Only allowlisted rewarders can schedule reward"
        );
        require(_rewards[rewardId].status == RewardStatus.UNINITIALIZED, "Reward has already been scheduled");
        _rewards[rewardId] = ScheduledReward({
            pool: pool,
            rewardsToken: rewardsToken,
            rewarder: msg.sender,
            amount: amount,
            startTime: startTime,
            status: RewardStatus.PENDING
        });
        rewardsToken.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardScheduled(rewardId, msg.sender, pool, rewardsToken, startTime, amount);
    }
}