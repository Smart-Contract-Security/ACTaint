pragma solidity 0.8.4;
import "../facades/LimboLike.sol";
import "../facades/LimboDAOLike.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract SoulReader {
  uint256 constant TERA = 1E12;
  struct Soul {
    uint256 lastRewardTimestamp; 
    uint256 accumulatedFlanPerShare;
    uint256 crossingThreshold; 
    uint256 soulType;
    uint256 state;
    uint256 flanPerSecond;
  }
  function getLimbo(address _limbo) internal pure returns (LimboLike) {
    return LimboLike(_limbo);
  }
  function SoulStats(address token, address _limbo)
    public
    view
    returns (
      uint256, 
      uint256, 
      uint256 
    )
  {
    LimboLike limbo = getLimbo(_limbo);
    uint256 latestIndex = limbo.latestIndex(token);
    (, , , , uint256 state, uint256 fps) = limbo.souls(token, latestIndex);
    uint256 stakeBalance = IERC20(token).balanceOf(address(limbo));
    return (state, stakeBalance, fps);
  }
  function CrossingParameters(address token, address _limbo)
    public
    view
    returns (
      uint256, 
      int256, 
      uint256 
    )
  {
    LimboLike limbo = getLimbo(_limbo);
    uint256 latestIndex = limbo.latestIndex(token);
    (, , , , , uint256 flanPerSecond) = limbo.souls(token, latestIndex);
    (, , int256 crossingBonusDelta, uint256 initialCrossingBonus, ) = limbo.tokenCrossingParameters(token, latestIndex);
    return (initialCrossingBonus, crossingBonusDelta, flanPerSecond);
  }
  function GetPendingReward(
    address account,
    address token,
    address _limbo
  ) external view returns (uint256) {
    LimboLike limbo = getLimbo(_limbo);
    uint256 latestIndex = limbo.latestIndex(token);
    Soul memory soul; 
    (soul.lastRewardTimestamp, soul.accumulatedFlanPerShare, , , soul.state, soul.flanPerSecond) = limbo.souls(
      token,
      latestIndex
    );
    (, uint256 stakingEndsTimestamp, , , ) = limbo.tokenCrossingParameters(token, latestIndex);
    uint256 finalTimeStamp = soul.state != 1 ? stakingEndsTimestamp : block.timestamp;
    uint256 limboBalance = IERC20(token).balanceOf(address(limbo));
    (uint256 stakedAmount, uint256 rewardDebt, ) = limbo.userInfo(token, account, latestIndex);
    if (limboBalance > 0) {
      soul.accumulatedFlanPerShare =
        soul.accumulatedFlanPerShare +
        (((finalTimeStamp - soul.lastRewardTimestamp) * soul.flanPerSecond * (1e12)) / limboBalance);
    }
    uint256 accumulated = ((stakedAmount * soul.accumulatedFlanPerShare) / (1e12));
    if (accumulated >= rewardDebt) return accumulated - rewardDebt;
    return 0;
  }
  function ExpectedCrossingBonus(
    address holder,
    address token,
    address _limbo
  ) external view returns (uint256 flanBonus) {
    LimboLike limbo = getLimbo(_limbo);
    uint256 latestIndex = limbo.latestIndex(token);
    (uint256 stakedAmount, , bool bonusPaid) = limbo.userInfo(token, holder, latestIndex);
    if (bonusPaid) return 0;
    uint256 bonusRate = ExpectedCrossingBonusRate(holder, token, _limbo);
    flanBonus = (bonusRate * stakedAmount) / TERA;
  }
  function ExpectedCrossingBonusRate(
    address holder,
    address token,
    address _limbo
  ) public view returns (uint256 bonusRate) {
    LimboLike limbo = getLimbo(_limbo);
    uint256 latestIndex = limbo.latestIndex(token);
    (uint256 stakedAmount, , bool bonusPaid) = limbo.userInfo(token, holder, latestIndex);
    if (bonusPaid) return 0;
    (uint256 stakingBegins, uint256 stakingEnds, int256 crossingBonusDelta, uint256 initialCrossingBonus, ) = limbo
      .tokenCrossingParameters(token, latestIndex);
    stakingEnds = stakingEnds == 0 ? block.timestamp : stakingEnds;
    stakingBegins = stakingBegins == 0 ? block.timestamp - 1 : stakingBegins;
    int256 accumulatedFlanPerTeraToken = crossingBonusDelta * int256(stakingEnds - stakingBegins);
    int256 finalFlanPerTeraToken = int256(initialCrossingBonus) +
      (stakedAmount > 0 ? accumulatedFlanPerTeraToken : int256(0));
    bonusRate = finalFlanPerTeraToken > 0 ? uint256(finalFlanPerTeraToken) : 0;
  }
}