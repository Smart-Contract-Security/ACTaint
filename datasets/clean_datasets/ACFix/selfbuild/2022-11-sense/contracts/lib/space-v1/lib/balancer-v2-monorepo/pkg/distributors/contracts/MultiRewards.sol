pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/math/Math.sol";
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/ReentrancyGuard.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/EnumerableSet.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/SafeMath.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/SafeERC20.sol";
import "@balancer-labs/v2-solidity-utils/contracts/openzeppelin/IERC20Permit.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IVault.sol";
import "@balancer-labs/v2-vault/contracts/interfaces/IAsset.sol";
import "./RewardsScheduler.sol";
import "./interfaces/IMultiRewards.sol";
import "./interfaces/IDistributorCallback.sol";
import "./interfaces/IDistributor.sol";
import "./MultiRewardsAuthorization.sol";
contract MultiRewards is IMultiRewards, IDistributor, ReentrancyGuard, MultiRewardsAuthorization {
    using FixedPoint for uint256;
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    struct Reward {
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }
    mapping(IERC20 => mapping(address => mapping(IERC20 => Reward))) public rewardData;
    mapping(IERC20 => EnumerableSet.AddressSet) private _rewardTokens;
    mapping(IERC20 => mapping(IERC20 => EnumerableSet.AddressSet)) private _rewarders;
    mapping(IERC20 => mapping(address => mapping(address => mapping(IERC20 => uint256)))) public userRewardPerTokenPaid;
    mapping(IERC20 => mapping(address => mapping(IERC20 => uint256))) public unpaidRewards;
    mapping(IERC20 => uint256) private _totalSupply;
    mapping(IERC20 => mapping(address => uint256)) private _balances;
    RewardsScheduler public immutable rewardsScheduler;
    constructor(IVault _vault)
        Authentication(bytes32(uint256(address(this))))
        MultiRewardsAuthorization(_vault)
    {
        rewardsScheduler = new RewardsScheduler();
    }
    function allowlistRewarder(
        IERC20 pool,
        IERC20 rewardsToken,
        address rewarder
    ) external override onlyAllowlisters(pool) {
        _allowlistRewarder(pool, rewardsToken, rewarder);
    }
    function isAllowlistedRewarder(
        IERC20 pool,
        IERC20 rewardsToken,
        address rewarder
    ) public view override returns (bool) {
        return _isAllowlistedRewarder(pool, rewardsToken, rewarder);
    }
    function addReward(
        IERC20 pool,
        IERC20 rewardsToken,
        uint256 rewardsDuration
    ) external override onlyAllowlistedRewarder(pool, rewardsToken) {
        require(rewardsDuration > 0, "reward rate must be nonzero");
        require(rewardData[pool][msg.sender][rewardsToken].rewardsDuration == 0, "Duplicate rewards token");
        _rewardTokens[pool].add(address(rewardsToken));
        _rewarders[pool][rewardsToken].add(msg.sender);
        rewardData[pool][msg.sender][rewardsToken].rewardsDuration = rewardsDuration;
        rewardsToken.approve(address(getVault()), type(uint256).max);
    }
    function totalSupply(IERC20 pool) external view returns (uint256) {
        return _totalSupply[pool];
    }
    function balanceOf(IERC20 pool, address account) external view returns (uint256) {
        return _balances[pool][account];
    }
    function lastTimeRewardApplicable(
        IERC20 pool,
        address rewarder,
        IERC20 rewardsToken
    ) public view returns (uint256) {
        return Math.min(block.timestamp, rewardData[pool][rewarder][rewardsToken].periodFinish);
    }
    function rewardPerToken(
        IERC20 pool,
        address rewarder,
        IERC20 rewardsToken
    ) public view returns (uint256) {
        if (_totalSupply[pool] == 0) {
            return rewardData[pool][rewarder][rewardsToken].rewardPerTokenStored;
        }
        uint256 unrewardedDuration = lastTimeRewardApplicable(pool, rewarder, rewardsToken) -
            rewardData[pool][rewarder][rewardsToken].lastUpdateTime;
        return
            rewardData[pool][rewarder][rewardsToken].rewardPerTokenStored.add(
                Math.mul(unrewardedDuration, rewardData[pool][rewarder][rewardsToken].rewardRate).divDown(
                    _totalSupply[pool]
                )
            );
    }
    function unaccountedForUnpaidRewards(
        IERC20 pool,
        address rewarder,
        address account,
        IERC20 rewardsToken
    ) public view returns (uint256) {
        return
            _balances[pool][account].mulDown(
                rewardPerToken(pool, rewarder, rewardsToken).sub(
                    userRewardPerTokenPaid[pool][rewarder][account][rewardsToken]
                )
            );
    }
    function totalEarned(
        IERC20 pool,
        address account,
        IERC20 rewardsToken
    ) public view returns (uint256 total) {
        uint256 rewardersLength = _rewarders[pool][rewardsToken].length();
        for (uint256 r; r < rewardersLength; r++) {
            total = total.add(
                unaccountedForUnpaidRewards(pool, _rewarders[pool][rewardsToken].unchecked_at(r), account, rewardsToken)
            );
        }
        total = total.add(unpaidRewards[pool][account][rewardsToken]);
    }
    function getRewardForDuration(
        IERC20 pool,
        address rewarder,
        IERC20 rewardsToken
    ) external view returns (uint256) {
        return
            Math.mul(
                rewardData[pool][rewarder][rewardsToken].rewardRate,
                rewardData[pool][rewarder][rewardsToken].rewardsDuration
            );
    }
    function stake(IERC20 pool, uint256 amount) external {
        stakeFor(pool, amount, msg.sender);
    }
    function stakeFor(
        IERC20 pool,
        uint256 amount,
        address receiver
    ) public nonReentrant updateReward(pool, receiver) {
        require(amount > 0, "Cannot stake 0");
        _totalSupply[pool] = _totalSupply[pool].add(amount);
        _balances[pool][receiver] = _balances[pool][receiver].add(amount);
        pool.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(address(pool), receiver, amount);
    }
    function stakeWithPermit(
        IERC20 pool,
        uint256 amount,
        uint256 deadline,
        address recipient,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(address(pool)).permit(msg.sender, address(this), amount, deadline, v, r, s);
        stakeFor(pool, amount, recipient);
    }
    function unstake(
        IERC20 pool,
        uint256 amount,
        address receiver
    ) public nonReentrant updateReward(pool, msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply[pool] = _totalSupply[pool].sub(amount);
        _balances[pool][msg.sender] = _balances[pool][msg.sender].sub(amount);
        pool.safeTransfer(receiver, amount);
        emit Withdrawn(address(pool), receiver, amount);
    }
    function getReward(IERC20[] calldata pools) external nonReentrant {
        _getReward(pools, msg.sender, false);
    }
    function getRewardAsInternalBalance(IERC20[] calldata pools) external nonReentrant {
        _getReward(pools, msg.sender, true);
    }
    function _rewardOpsCount(IERC20[] calldata pools) internal view returns (uint256 opsCount) {
        for (uint256 p; p < pools.length; p++) {
            IERC20 pool = pools[p];
            uint256 rewardTokensLength = _rewardTokens[pool].length();
            opsCount += rewardTokensLength;
        }
    }
    function _getReward(
        IERC20[] calldata pools,
        address recipient,
        bool asInternalBalance
    ) internal {
        IVault.UserBalanceOpKind kind = asInternalBalance
            ? IVault.UserBalanceOpKind.TRANSFER_INTERNAL
            : IVault.UserBalanceOpKind.WITHDRAW_INTERNAL;
        IVault.UserBalanceOp[] memory ops = new IVault.UserBalanceOp[](_rewardOpsCount(pools));
        uint256 idx;
        for (uint256 p; p < pools.length; p++) {
            IERC20 pool = pools[p];
            uint256 tokensLength = _rewardTokens[pool].length();
            for (uint256 t; t < tokensLength; t++) {
                IERC20 rewardsToken = IERC20(_rewardTokens[pool].unchecked_at(t));
                _updateReward(pool, msg.sender, rewardsToken);
                uint256 reward = unpaidRewards[pool][msg.sender][rewardsToken];
                if (reward > 0) {
                    unpaidRewards[pool][msg.sender][rewardsToken] = 0;
                    emit RewardPaid(msg.sender, address(rewardsToken), reward);
                }
                ops[idx] = IVault.UserBalanceOp({
                    asset: IAsset(address(rewardsToken)),
                    amount: reward,
                    sender: address(this),
                    recipient: payable(recipient),
                    kind: kind
                });
                idx++;
            }
        }
        getVault().manageUserBalance(ops);
    }
    function getRewardWithCallback(
        IERC20[] calldata pools,
        IDistributorCallback callbackContract,
        bytes calldata callbackData
    ) external nonReentrant {
        _getReward(pools, address(callbackContract), true);
        callbackContract.distributorCallback(callbackData);
    }
    function exit(IERC20[] calldata pools) external {
        for (uint256 p; p < pools.length; p++) {
            IERC20 pool = pools[p];
            unstake(pool, _balances[pool][msg.sender], msg.sender);
        }
        _getReward(pools, msg.sender, false);
    }
    function exitWithCallback(
        IERC20[] calldata pools,
        IDistributorCallback callbackContract,
        bytes calldata callbackData
    ) external {
        for (uint256 p; p < pools.length; p++) {
            IERC20 pool = pools[p];
            unstake(pool, _balances[pool][msg.sender], address(callbackContract));
        }
        _getReward(pools, msg.sender, false);
        callbackContract.distributorCallback(callbackData);
    }
    function notifyRewardAmount(
        IERC20 pool,
        IERC20 rewardsToken,
        uint256 reward,
        address rewarder
    ) external override updateReward(pool, address(0)) {
        require(
            msg.sender == rewarder || msg.sender == address(rewardsScheduler),
            "Rewarder must be sender, or rewards scheduler"
        );
        require(_rewarders[pool][rewardsToken].contains(rewarder), "Reward must be configured with addReward");
        rewardsToken.safeTransferFrom(msg.sender, address(this), reward);
        IVault.UserBalanceOp[] memory ops = new IVault.UserBalanceOp[](1);
        ops[0] = IVault.UserBalanceOp({
            asset: IAsset(address(rewardsToken)),
            amount: reward,
            sender: address(this),
            recipient: payable(address(this)),
            kind: IVault.UserBalanceOpKind.DEPOSIT_INTERNAL
        });
        getVault().manageUserBalance(ops);
        if (block.timestamp >= rewardData[pool][rewarder][rewardsToken].periodFinish) {
            rewardData[pool][rewarder][rewardsToken].rewardRate = Math.divDown(
                reward,
                rewardData[pool][rewarder][rewardsToken].rewardsDuration
            );
        } else {
            uint256 remaining = rewardData[pool][rewarder][rewardsToken].periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mulDown(rewardData[pool][rewarder][rewardsToken].rewardRate);
            rewardData[pool][rewarder][rewardsToken].rewardRate = Math.divDown(
                reward.add(leftover),
                rewardData[pool][rewarder][rewardsToken].rewardsDuration
            );
        }
        rewardData[pool][rewarder][rewardsToken].lastUpdateTime = block.timestamp;
        rewardData[pool][rewarder][rewardsToken].periodFinish = block.timestamp.add(
            rewardData[pool][rewarder][rewardsToken].rewardsDuration
        );
        emit RewardAdded(address(rewardsToken), reward);
    }
    function setRewardsDuration(
        IERC20 pool,
        IERC20 rewardsToken,
        uint256 rewardsDuration
    ) external {
        require(
            block.timestamp > rewardData[pool][msg.sender][rewardsToken].periodFinish,
            "Reward period still active"
        );
        require(rewardsDuration > 0, "Reward duration must be non-zero");
        rewardData[pool][msg.sender][rewardsToken].rewardsDuration = rewardsDuration;
        emit RewardsDurationUpdated(
            address(pool),
            address(rewardsToken),
            rewardData[pool][msg.sender][rewardsToken].rewardsDuration
        );
    }
    function _updateReward(
        IERC20 pool,
        address account,
        IERC20 token
    ) internal {
        uint256 totalUnpaidRewards;
        for (uint256 r; r < _rewarders[pool][token].length(); r++) {
            address rewarder = _rewarders[pool][token].unchecked_at(r);
            rewardData[pool][rewarder][token].rewardPerTokenStored = rewardPerToken(pool, rewarder, token);
            rewardData[pool][rewarder][token].lastUpdateTime = lastTimeRewardApplicable(pool, rewarder, token);
            if (account != address(0)) {
                totalUnpaidRewards = totalUnpaidRewards.add(
                    unaccountedForUnpaidRewards(pool, rewarder, account, token)
                );
                userRewardPerTokenPaid[pool][rewarder][account][token] = rewardData[pool][rewarder][token]
                    .rewardPerTokenStored;
            }
        }
        unpaidRewards[pool][account][token] = totalUnpaidRewards;
    }
    modifier updateReward(IERC20 pool, address account) {
        uint256 rewardTokensLength = _rewardTokens[pool].length();
        for (uint256 t; t < rewardTokensLength; t++) {
            IERC20 rewardToken = IERC20(_rewardTokens[pool].unchecked_at(t));
            _updateReward(pool, account, rewardToken);
        }
        _;
    }
    event Staked(address indexed pool, address indexed account, uint256 amount);
    event Withdrawn(address indexed pool, address indexed account, uint256 amount);
    event RewardsDurationUpdated(address indexed pool, address token, uint256 newDuration);
}