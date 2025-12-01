pragma solidity 0.8.4;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./facades/LimboDAOLike.sol";
import "./facades/Burnable.sol";
import "./facades/BehodlerLike.sol";
import "./facades/FlanLike.sol";
import "./facades/UniPairLike.sol";
import "./facades/MigratorLike.sol";
import "./facades/AMMHelper.sol";
import "./facades/AngbandLike.sol";
import "./facades/LimboAddTokenToBehodlerPowerLike.sol";
import "./DAO/Governable.sol";
import "./facades/FlashGovernanceArbiterLike.sol";
enum SoulState {
  calibration,
  staking,
  waitingToCross,
  crossedOver
}
enum SoulType {
  uninitialized,
  threshold, 
  perpetual 
}
struct Soul {
  uint256 lastRewardTimestamp;
  uint256 accumulatedFlanPerShare;
  uint256 crossingThreshold; 
  SoulType soulType;
  SoulState state;
  uint256 flanPerSecond; 
}
struct CrossingParameters {
  uint256 stakingBeginsTimestamp; 
  uint256 stakingEndsTimestamp;
  int256 crossingBonusDelta; 
  uint256 initialCrossingBonus; 
  bool burnable;
}
struct CrossingConfig {
  address behodler;
  uint256 SCX_fee;
  uint256 migrationInvocationReward; 
  uint256 crossingMigrationDelay; 
  address morgothPower;
  address angband;
  address ammHelper;
  uint16 rectangleOfFairnessInflationFactor; 
}
library SoulLib {
  function set(
    Soul storage soul,
    uint256 crossingThreshold,
    uint256 soulType,
    uint256 state,
    uint256 fps
  ) external {
    soul.crossingThreshold = crossingThreshold;
    soul.flanPerSecond = fps;
    soul.state = SoulState(state);
    soul.soulType = SoulType(soulType);
  }
}
library CrossingLib {
  function set(
    CrossingParameters storage params,
    FlashGovernanceArbiterLike flashGoverner,
    Soul storage soul,
    uint256 initialCrossingBonus,
    int256 crossingBonusDelta,
    bool burnable,
    uint256 crossingThreshold
  ) external {
    flashGoverner.enforceTolerance(initialCrossingBonus, params.initialCrossingBonus);
    flashGoverner.enforceToleranceInt(crossingBonusDelta, params.crossingBonusDelta);
    params.initialCrossingBonus = initialCrossingBonus;
    params.crossingBonusDelta = crossingBonusDelta;
    params.burnable = burnable;
    flashGoverner.enforceTolerance(crossingThreshold, soul.crossingThreshold);
    soul.crossingThreshold = crossingThreshold;
  }
}
library MigrationLib {
  function migrate(
    address token,
    LimboAddTokenToBehodlerPowerLike power,
    CrossingParameters memory crossingParams,
    CrossingConfig memory crossingConfig,
    FlanLike flan,
    uint256 RectangleOfFairness,
    Soul storage soul
  ) external returns (uint256, uint256) {
    power.parameterize(token, crossingParams.burnable);
    uint256 tokenBalance = IERC20(token).balanceOf(address(this));
    IERC20(token).transfer(address(crossingConfig.morgothPower), tokenBalance);
    AngbandLike(crossingConfig.angband).executePower(address(crossingConfig.morgothPower));
    uint256 scxMinted = IERC20(address(crossingConfig.behodler)).balanceOf(address(this));
    uint256 adjustedRectangle = ((crossingConfig.rectangleOfFairnessInflationFactor) * RectangleOfFairness) / 100;
    if (scxMinted <= adjustedRectangle) {
      adjustedRectangle = scxMinted / 2;
    }
    uint256 excessSCX = scxMinted - adjustedRectangle;
    require(BehodlerLike(crossingConfig.behodler).burn(excessSCX), "E8");
    IERC20(crossingConfig.behodler).transfer(crossingConfig.ammHelper, adjustedRectangle);
    uint256 lpMinted = AMMHelper(crossingConfig.ammHelper).stabilizeFlan(adjustedRectangle);
    require(flan.mint(msg.sender, crossingConfig.migrationInvocationReward), "E9");
    soul.state = SoulState.crossedOver;
    return (tokenBalance, lpMinted);
  }
}
contract Limbo is Governable {
  using SafeERC20 for IERC20;
  using SoulLib for Soul;
  using MigrationLib for address;
  using CrossingLib for CrossingParameters;
  event SoulUpdated(address soul, uint256 fps);
  event Staked(address staker, address soul, uint256 amount);
  event Unstaked(address staker, address soul, uint256 amount);
  event TokenListed(address token, uint256 amount, uint256 scxfln_LP_minted);
  event ClaimedReward(address staker, address soul, uint256 index, uint256 amount);
  event BonusPaid(address token, uint256 index, address recipient, uint256 bonus);
  struct User {
    uint256 stakedAmount;
    uint256 rewardDebt;
    bool bonusPaid;
  }
  uint256 constant TERA = 1E12;
  uint256 constant RectangleOfFairness = 30 ether; 
  bool protocolEnabled = true;
  CrossingConfig public crossingConfig;
  mapping(address => mapping(uint256 => Soul)) public souls;
  mapping(address => uint256) public latestIndex;
  mapping(address => mapping(address => mapping(uint256 => User))) public userInfo;
  mapping(address => mapping(uint256 => CrossingParameters)) public tokenCrossingParameters;
  mapping(address => mapping(address => mapping(address => uint256))) unstakeApproval;
  FlanLike Flan;
  modifier enabled() {
    require(protocolEnabled, "EF");
    _;
  }
  function attemptToTargetAPY(
    address token,
    uint256 desiredAPY,
    uint256 daiThreshold
  ) public governanceApproved(false) {
    Soul storage soul = currentSoul(token);
    require(soul.soulType == SoulType.threshold, "EI");
    uint256 fps = AMMHelper(crossingConfig.ammHelper).minAPY_to_FPS(desiredAPY, daiThreshold);
    flashGoverner.enforceTolerance(soul.flanPerSecond, fps);
    soul.flanPerSecond = fps;
  }
  function updateSoul(address token) public {
    Soul storage s = currentSoul(token);
    updateSoul(token, s);
  }
  function updateSoul(address token, Soul storage soul) internal {
    require(soul.soulType != SoulType.uninitialized, "E1");
    uint256 finalTimeStamp = block.timestamp;
    if (soul.state != SoulState.staking) {
      finalTimeStamp = tokenCrossingParameters[token][latestIndex[token]].stakingEndsTimestamp;
    }
    uint256 balance = IERC20(token).balanceOf(address(this));
    if (balance > 0) {
      uint256 flanReward = (finalTimeStamp - soul.lastRewardTimestamp) * soul.flanPerSecond;
      soul.accumulatedFlanPerShare = soul.accumulatedFlanPerShare + ((flanReward * TERA) / balance);
    }
    soul.lastRewardTimestamp = finalTimeStamp;
  }
  constructor(address flan, address limboDAO) Governable(limboDAO) {
    Flan = FlanLike(flan);
  }
  function configureCrossingConfig(
    address behodler,
    address angband,
    address ammHelper,
    address morgothPower,
    uint256 migrationInvocationReward,
    uint256 crossingMigrationDelay,
    uint16 rectInflationFactor 
  ) public onlySuccessfulProposal {
    crossingConfig.migrationInvocationReward = migrationInvocationReward * (1 ether);
    crossingConfig.behodler = behodler;
    crossingConfig.crossingMigrationDelay = crossingMigrationDelay;
    crossingConfig.angband = angband;
    crossingConfig.ammHelper = ammHelper;
    crossingConfig.morgothPower = morgothPower;
    require(rectInflationFactor <= 10000, "E6");
    crossingConfig.rectangleOfFairnessInflationFactor = rectInflationFactor;
  }
  function disableProtocol() public governanceApproved(true) {
    protocolEnabled = false;
  }
  function enableProtocol() public onlySuccessfulProposal {
    protocolEnabled = true;
  }
  function adjustSoul(
    address token,
    uint256 initialCrossingBonus,
    int256 crossingBonusDelta,
    uint256 fps
  ) public governanceApproved(false) {
    Soul storage soul = currentSoul(token);
    flashGoverner.enforceTolerance(soul.flanPerSecond, fps);
    soul.flanPerSecond = fps;
    CrossingParameters storage params = tokenCrossingParameters[token][latestIndex[token]];
    flashGoverner.enforceTolerance(params.initialCrossingBonus, initialCrossingBonus);
    flashGoverner.enforceTolerance(
      uint256(params.crossingBonusDelta < 0 ? params.crossingBonusDelta * -1 : params.crossingBonusDelta),
      uint256(crossingBonusDelta < 0 ? crossingBonusDelta * -1 : crossingBonusDelta)
    );
    params.initialCrossingBonus = initialCrossingBonus;
    params.crossingBonusDelta = crossingBonusDelta;
  }
  function configureSoul(
    address token,
    uint256 crossingThreshold,
    uint256 soulType,
    uint256 state,
    uint256 index,
    uint256 fps
  ) public onlySoulUpdateProposal {
    {
      latestIndex[token] = index > latestIndex[token] ? latestIndex[token] + 1 : latestIndex[token];
      Soul storage soul = currentSoul(token);
      bool fallingBack = soul.state != SoulState.calibration && SoulState(state) == SoulState.calibration;
      soul.set(crossingThreshold, soulType, state, fps);
      if (SoulState(state) == SoulState.staking) {
        tokenCrossingParameters[token][latestIndex[token]].stakingBeginsTimestamp = block.timestamp;
      }
      if(fallingBack){
         tokenCrossingParameters[token][latestIndex[token]].stakingEndsTimestamp = block.timestamp;
      }
    }
    emit SoulUpdated(token, fps);
  }
  function configureCrossingParameters(
    address token,
    uint256 initialCrossingBonus,
    int256 crossingBonusDelta,
    bool burnable,
    uint256 crossingThreshold
  ) public governanceApproved(false) {
    CrossingParameters storage params = tokenCrossingParameters[token][latestIndex[token]];
    Soul storage soul = currentSoul(token);
    params.set(flashGoverner, soul, initialCrossingBonus, crossingBonusDelta, burnable, crossingThreshold);
  }
  function stake(address token, uint256 amount) public enabled {
    Soul storage soul = currentSoul(token);
    require(soul.state == SoulState.staking, "E2");
    updateSoul(token, soul);
    uint256 currentIndex = latestIndex[token];
    User storage user = userInfo[token][msg.sender][currentIndex];
    if (amount > 0) {
      uint256 pending = getPending(user, soul);
      if (pending > 0) {
        Flan.mint(msg.sender, pending);
      }
      uint256 oldBalance = IERC20(token).balanceOf(address(this));
      IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
      uint256 newBalance = IERC20(token).balanceOf(address(this));
      user.stakedAmount = user.stakedAmount + newBalance - oldBalance; 
      if (soul.soulType == SoulType.threshold && newBalance > soul.crossingThreshold) {
        soul.state = SoulState.waitingToCross;
        tokenCrossingParameters[token][latestIndex[token]].stakingEndsTimestamp = block.timestamp;
      }
    }
    user.rewardDebt = (user.stakedAmount * soul.accumulatedFlanPerShare) / TERA;
    emit Staked(msg.sender, token, user.stakedAmount);
  }
  function unstake(address token, uint256 amount) public enabled {
    _unstake(token, amount, msg.sender, msg.sender);
  }
  function unstakeFor(
    address token,
    uint256 amount,
    address holder
  ) public {
    _unstake(token, amount, msg.sender, holder);
  }
  function _unstake(
    address token,
    uint256 amount,
    address unstaker,
    address holder
  ) internal {
    if (unstaker != holder) {
      unstakeApproval[token][holder][unstaker] -= amount;
    }
    Soul storage soul = currentSoul(token);
    require(soul.state == SoulState.calibration || soul.state == SoulState.staking, "E2");
    updateSoul(token, soul);
    User storage user = userInfo[token][holder][latestIndex[token]];
    require(user.stakedAmount >= amount, "E4");
    uint256 pending = getPending(user, soul);
    if (pending > 0 && amount > 0) {
      user.stakedAmount = user.stakedAmount - amount;
      IERC20(token).safeTransfer(address(unstaker), amount);
      rewardAdjustDebt(unstaker, pending, soul.accumulatedFlanPerShare, user);
      emit Unstaked(unstaker, token, amount);
    }
  }
  function claimReward(address token, uint256 index) public enabled {
    Soul storage soul = souls[token][index];
    updateSoul(token, soul);
    User storage user = userInfo[token][msg.sender][index];
    uint256 pending = getPending(user, soul);
    if (pending > 0) {
      rewardAdjustDebt(msg.sender, pending, soul.accumulatedFlanPerShare, user);
      emit ClaimedReward(msg.sender, token, index, pending);
    }
  }
  function claimBonus(address token, uint256 index) public enabled {
    Soul storage soul = souls[token][index];
    CrossingParameters storage crossing = tokenCrossingParameters[token][index];
    require(soul.state == SoulState.crossedOver || soul.state == SoulState.waitingToCross, "E2");
    User storage user = userInfo[token][msg.sender][index];
    require(!user.bonusPaid, "E5");
    user.bonusPaid = true;
    int256 accumulatedFlanPerTeraToken = crossing.crossingBonusDelta *
      int256(crossing.stakingEndsTimestamp - crossing.stakingBeginsTimestamp);
    require(accumulatedFlanPerTeraToken * crossing.crossingBonusDelta >= 0, "E6");
    int256 finalFlanPerTeraToken = int256(crossing.initialCrossingBonus) + accumulatedFlanPerTeraToken;
    uint256 flanBonus = 0;
    require(finalFlanPerTeraToken > 0, "ED");
    flanBonus = uint256((int256(user.stakedAmount) * finalFlanPerTeraToken)) / TERA;
    Flan.mint(msg.sender, flanBonus);
    emit BonusPaid(token, index, msg.sender, flanBonus);
  }
  function claimSecondaryRewards(address token) public {
    SoulState state = currentSoul(token).state;
    require(state == SoulState.calibration || state == SoulState.crossedOver, "E7");
    uint256 balance = IERC20(token).balanceOf(address(this));
    IERC20(token).safeTransfer(crossingConfig.ammHelper, balance);
    AMMHelper(crossingConfig.ammHelper).buyFlanAndBurn(token, balance, msg.sender);
  }
  function migrate(address token) public enabled {
    Soul storage soul = currentSoul(token);
    require(soul.soulType == SoulType.threshold, "EB");
    require(soul.state == SoulState.waitingToCross, "E2");
    require(
      block.timestamp - tokenCrossingParameters[token][latestIndex[token]].stakingEndsTimestamp >
        crossingConfig.crossingMigrationDelay,
      "EC"
    );
    (uint256 tokenBalance, uint256 lpMinted) = token.migrate(
      LimboAddTokenToBehodlerPowerLike(crossingConfig.morgothPower),
      tokenCrossingParameters[token][latestIndex[token]],
      crossingConfig,
      Flan,
      RectangleOfFairness,
      soul
    );
    emit TokenListed(token, tokenBalance, lpMinted);
  }
  function approveUnstake(
    address soul,
    address unstaker,
    uint256 amount
  ) external {
    unstakeApproval[soul][msg.sender][unstaker] = amount; 
  }
  function rewardAdjustDebt(
    address recipient,
    uint256 pending,
    uint256 accumulatedFlanPerShare,
    User storage user
  ) internal {
    Flan.mint(recipient, pending);
    user.rewardDebt = (user.stakedAmount * accumulatedFlanPerShare) / TERA;
  }
  function currentSoul(address token) internal view returns (Soul storage) {
    return souls[token][latestIndex[token]];
  }
  function getPending(User memory user, Soul memory soul) internal pure returns (uint256) {
    return ((user.stakedAmount * soul.accumulatedFlanPerShare) / TERA) - user.rewardDebt;
  }
}