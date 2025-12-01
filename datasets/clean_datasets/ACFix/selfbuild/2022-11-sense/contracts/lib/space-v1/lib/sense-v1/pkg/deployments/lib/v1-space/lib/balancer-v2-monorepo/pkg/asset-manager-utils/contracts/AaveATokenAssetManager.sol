import "./aave/ILendingPoolAddressesProvider.sol";
import "./aave/ILendingPool.sol";
import "./aave/IAaveIncentivesController.sol";
import "./RewardsAssetManager.sol";
import "@balancer-labs/v2-distributors/contracts/interfaces/IMultiRewards.sol";
pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
contract AaveATokenAssetManager is RewardsAssetManager {
    uint16 public constant REFERRAL_CODE = 0;
    IAaveIncentivesController public immutable aaveIncentives;
    ILendingPool public immutable lendingPool;
    IERC20 public immutable aToken;
    IERC20 public immutable stkAave;
    IMultiRewards public distributor;
    constructor(
        IVault vault,
        IERC20 token,
        ILendingPool _lendingPool,
        IAaveIncentivesController _aaveIncentives
    ) RewardsAssetManager(vault, bytes32(0), token) {
        lendingPool = _lendingPool;
        aToken = IERC20(_lendingPool.getReserveData(address(token)).aTokenAddress);
        aaveIncentives = _aaveIncentives;
        stkAave = IERC20(_aaveIncentives.REWARD_TOKEN());
        token.approve(address(_lendingPool), type(uint256).max);
    }
    function initialize(bytes32 poolId, address rewardsDistributor) public {
        _initialize(poolId);
        distributor = IMultiRewards(rewardsDistributor);
        IERC20 poolAddress = IERC20(uint256(poolId) >> (12 * 8));
        distributor.allowlistRewarder(poolAddress, stkAave, address(this));
        distributor.addReward(poolAddress, stkAave, 1);
        stkAave.approve(rewardsDistributor, type(uint256).max);
    }
    function _invest(uint256 amount, uint256) internal override returns (uint256) {
        lendingPool.deposit(address(getToken()), amount, address(this), REFERRAL_CODE);
        return amount;
    }
    function _divest(uint256 amount, uint256) internal override returns (uint256) {
        return lendingPool.withdraw(address(getToken()), amount, address(this));
    }
    function _getAUM() internal view override returns (uint256) {
        return aToken.balanceOf(address(this));
    }
    function claimRewards() public {
        address[] memory assets = new address[](1);
        assets[0] = address(aToken);
        aaveIncentives.claimRewards(assets, type(uint256).max, address(this));
        distributor.notifyRewardAmount(
            IERC20(getPoolAddress()),
            stkAave,
            stkAave.balanceOf(address(this)),
            address(this)
        );
    }
}