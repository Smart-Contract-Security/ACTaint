pragma solidity 0.8.17;
import {EnumerableSetUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeableBase} from "../../UUPSUpgradeableBase.sol";
import {SToken} from "./SToken.sol";
import {IPremiumCalculator} from "../../interfaces/IPremiumCalculator.sol";
import {IReferenceLendingPools, LendingPoolStatus, ProtectionPurchaseParams} from "../../interfaces/IReferenceLendingPools.sol";
import {IProtectionPoolCycleManager, ProtectionPoolCycleState} from "../../interfaces/IProtectionPoolCycleManager.sol";
import {IProtectionPool, ProtectionPoolParams, ProtectionPoolInfo, ProtectionInfo, LendingPoolDetail, WithdrawalCycleDetail, ProtectionBuyerAccount, ProtectionPoolPhase} from "../../interfaces/IProtectionPool.sol";
import {IDefaultStateManager} from "../../interfaces/IDefaultStateManager.sol";
import "../../libraries/AccruedPremiumCalculator.sol";
import "../../libraries/Constants.sol";
import "../../libraries/ProtectionPoolHelper.sol";
import "hardhat/console.sol";
contract ProtectionPool is
  UUPSUpgradeableBase,
  ReentrancyGuardUpgradeable,
  IProtectionPool,
  SToken
{
  using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
  using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
  IPremiumCalculator private premiumCalculator;
  IProtectionPoolCycleManager private poolCycleManager;
  IDefaultStateManager private defaultStateManager;
  ProtectionPoolInfo private poolInfo;
  uint256 private totalPremium;
  uint256 private totalProtection;
  uint256 private totalPremiumAccrued;
  uint256 private totalSTokenUnderlying;
  ProtectionInfo[] private protectionInfos;
  mapping(uint256 => WithdrawalCycleDetail) private withdrawalCycleDetails;
  mapping(address => LendingPoolDetail) private lendingPoolDetails;
  mapping(address => ProtectionBuyerAccount) private protectionBuyerAccounts;
  modifier whenPoolIsOpen() {
    ProtectionPoolCycleState cycleState = poolCycleManager
      .calculateAndSetPoolCycleState(address(this));
    if (cycleState != ProtectionPoolCycleState.Open) {
      revert ProtectionPoolIsNotOpen();
    }
    _;
  }
  modifier onlyDefaultStateManager() {
    if (msg.sender != address(defaultStateManager)) {
      revert OnlyDefaultStateManager(msg.sender);
    }
    _;
  }
  function initialize(
    address _owner,
    ProtectionPoolInfo calldata _poolInfo,
    IPremiumCalculator _premiumCalculator,
    IProtectionPoolCycleManager _poolCycleManager,
    IDefaultStateManager _defaultStateManager,
    string calldata _name,
    string calldata _symbol
  ) external override initializer {
    __UUPSUpgradeableBase_init();
    __ReentrancyGuard_init();
    __sToken_init(_name, _symbol);
    poolInfo = _poolInfo;
    premiumCalculator = _premiumCalculator;
    poolCycleManager = _poolCycleManager;
    defaultStateManager = _defaultStateManager;
    emit ProtectionPoolInitialized(
      _name,
      _symbol,
      poolInfo.underlyingToken,
      poolInfo.referenceLendingPools
    );
    _transferOwnership(_owner);
    protectionInfos.push();
  }
  function buyProtection(
    ProtectionPurchaseParams calldata _protectionPurchaseParams,
    uint256 _maxPremiumAmount
  ) external override whenNotPaused nonReentrant {
    _verifyAndCreateProtection(
      block.timestamp,
      _protectionPurchaseParams,
      _maxPremiumAmount,
      false
    );
  }
  function renewProtection(
    ProtectionPurchaseParams calldata _protectionPurchaseParams,
    uint256 _maxPremiumAmount
  ) external override whenNotPaused nonReentrant {
    ProtectionPoolHelper.verifyBuyerCanRenewProtection(
      protectionBuyerAccounts,
      protectionInfos,
      _protectionPurchaseParams,
      poolInfo.params.protectionRenewalGracePeriodInSeconds
    );
    _verifyAndCreateProtection(
      block.timestamp,
      _protectionPurchaseParams,
      _maxPremiumAmount,
      true
    );
  }
  function deposit(uint256 _underlyingAmount, address _receiver)
    external
    override
    whenNotPaused
    nonReentrant
  {
    _deposit(_underlyingAmount, _receiver);
  }
  function requestWithdrawal(uint256 _sTokenAmount)
    external
    override
    whenNotPaused
  {
    _requestWithdrawal(_sTokenAmount);
  }
  function depositAndRequestWithdrawal(
    uint256 _underlyingAmountToDeposit,
    uint256 _sTokenAmountToWithdraw
  ) external virtual override whenNotPaused nonReentrant {
    _deposit(_underlyingAmountToDeposit, msg.sender);
    _requestWithdrawal(_sTokenAmountToWithdraw);
  }
  function withdraw(uint256 _sTokenWithdrawalAmount, address _receiver)
    external
    override
    whenPoolIsOpen
    whenNotPaused
    nonReentrant
  {
    uint256 _currentCycleIndex = poolCycleManager.getCurrentCycleIndex(
      address(this)
    );
    WithdrawalCycleDetail storage withdrawalCycle = withdrawalCycleDetails[
      _currentCycleIndex
    ];
    uint256 _sTokenRequested = withdrawalCycle.withdrawalRequests[msg.sender];
    if (_sTokenRequested == 0) {
      revert NoWithdrawalRequested(msg.sender, _currentCycleIndex);
    }
    if (_sTokenWithdrawalAmount > _sTokenRequested) {
      revert WithdrawalHigherThanRequested(msg.sender, _sTokenRequested);
    }
    uint256 _underlyingAmountToTransfer = convertToUnderlying(
      _sTokenWithdrawalAmount
    );
    _burn(msg.sender, _sTokenWithdrawalAmount);
    totalSTokenUnderlying -= _underlyingAmountToTransfer;
    withdrawalCycle.withdrawalRequests[msg.sender] -= _sTokenWithdrawalAmount;
    withdrawalCycle.totalSTokenRequested -= _sTokenWithdrawalAmount;
    poolInfo.underlyingToken.safeTransfer(
      _receiver,
      _underlyingAmountToTransfer
    );
    emit WithdrawalMade(msg.sender, _sTokenWithdrawalAmount, _receiver);
  }
  function accruePremiumAndExpireProtections(address[] memory _lendingPools)
    external
    override
  {
    if (_lendingPools.length == 0) {
      _lendingPools = poolInfo.referenceLendingPools.getLendingPools();
    }
    uint256 _totalPremiumAccrued;
    uint256 _totalProtectionRemoved;
    uint256 length = _lendingPools.length;
    for (uint256 _lendingPoolIndex; _lendingPoolIndex < length; ) {
      address _lendingPool = _lendingPools[_lendingPoolIndex];
      LendingPoolDetail storage lendingPoolDetail = lendingPoolDetails[
        _lendingPool
      ];
      uint256 _latestPaymentTimestamp = poolInfo
        .referenceLendingPools
        .getLatestPaymentTimestamp(_lendingPool);
      uint256 _lastPremiumAccrualTimestamp = lendingPoolDetail
        .lastPremiumAccrualTimestamp;
      console.log(
        "lendingPool: %s, lastPremiumAccrualTimestamp: %s, latestPaymentTimestamp: %s",
        _lendingPool,
        _lastPremiumAccrualTimestamp,
        _latestPaymentTimestamp
      );
      (
        uint256 _accruedPremiumForLendingPool,
        uint256 _totalProtectionRemovedForLendingPool
      ) = _accruePremiumAndExpireProtections(
          lendingPoolDetail,
          _lastPremiumAccrualTimestamp,
          _latestPaymentTimestamp
        );
      _totalPremiumAccrued += _accruedPremiumForLendingPool;
      _totalProtectionRemoved += _totalProtectionRemovedForLendingPool;
      if (_accruedPremiumForLendingPool > 0) {
        lendingPoolDetail.lastPremiumAccrualTimestamp = _latestPaymentTimestamp;
        emit PremiumAccrued(_lendingPool, _latestPaymentTimestamp);
      }
      unchecked {
        ++_lendingPoolIndex;
      }
    }
    if (_totalPremiumAccrued > 0) {
      totalPremiumAccrued += _totalPremiumAccrued;
      totalSTokenUnderlying += _totalPremiumAccrued;
    }
    if (_totalProtectionRemoved > 0) {
      totalProtection -= _totalProtectionRemoved;
    }
  }
  function lockCapital(address _lendingPoolAddress)
    external
    payable
    override
    onlyDefaultStateManager
    whenNotPaused
    returns (uint256 _lockedAmount, uint256 _snapshotId)
  {
    _snapshotId = _snapshot();
    LendingPoolDetail storage lendingPoolDetail = lendingPoolDetails[
      _lendingPoolAddress
    ];
    EnumerableSetUpgradeable.UintSet
      storage activeProtectionIndexes = lendingPoolDetail
        .activeProtectionIndexes;
    uint256 _length = activeProtectionIndexes.length();
    for (uint256 i; i < _length; ) {
      uint256 _protectionIndex = activeProtectionIndexes.at(i);
      ProtectionInfo storage protectionInfo = protectionInfos[_protectionIndex];
      uint256 _remainingPrincipal = poolInfo
        .referenceLendingPools
        .calculateRemainingPrincipal(
          _lendingPoolAddress,
          protectionInfo.buyer,
          protectionInfo.purchaseParams.nftLpTokenId
        );
      uint256 _protectionAmount = protectionInfo
        .purchaseParams
        .protectionAmount;
      uint256 _lockedAmountPerProtection = _protectionAmount <
        _remainingPrincipal
        ? _protectionAmount
        : _remainingPrincipal;
      _lockedAmount += _lockedAmountPerProtection;
      unchecked {
        ++i;
      }
    }
    unchecked {
      if (totalSTokenUnderlying < _lockedAmount) {
        _lockedAmount = totalSTokenUnderlying;
        totalSTokenUnderlying = 0;
      } else {
        totalSTokenUnderlying -= _lockedAmount;
      }
    }
  }
  function claimUnlockedCapital(address _receiver)
    external
    override
    whenNotPaused
  {
    uint256 _claimableAmount = defaultStateManager
      .calculateAndClaimUnlockedCapital(msg.sender);
    if (_claimableAmount > 0) {
      console.log(
        "Total sToken underlying: %s, claimableAmount: %s",
        totalSTokenUnderlying,
        _claimableAmount
      );
      poolInfo.underlyingToken.safeTransfer(_receiver, _claimableAmount);
    }
  }
  function pause() external payable onlyOwner {
    _pause();
  }
  function unpause() external payable onlyOwner {
    _unpause();
  }
  function updateLeverageRatioParams(
    uint256 _leverageRatioFloor,
    uint256 _leverageRatioCeiling,
    uint256 _leverageRatioBuffer
  ) external payable onlyOwner {
    poolInfo.params.leverageRatioFloor = _leverageRatioFloor;
    poolInfo.params.leverageRatioCeiling = _leverageRatioCeiling;
    poolInfo.params.leverageRatioBuffer = _leverageRatioBuffer;
  }
  function updateRiskPremiumParams(
    uint256 _curvature,
    uint256 _minCarapaceRiskPremiumPercent,
    uint256 _underlyingRiskPremiumPercent
  ) external payable onlyOwner {
    poolInfo.params.curvature = _curvature;
    poolInfo
      .params
      .minCarapaceRiskPremiumPercent = _minCarapaceRiskPremiumPercent;
    poolInfo
      .params
      .underlyingRiskPremiumPercent = _underlyingRiskPremiumPercent;
  }
  function updateMinRequiredCapital(uint256 _minRequiredCapital)
    external
    payable
    onlyOwner
  {
    poolInfo.params.minRequiredCapital = _minRequiredCapital;
  }
  function movePoolPhase()
    external
    payable
    onlyOwner
    returns (ProtectionPoolPhase _newPhase)
  {
    ProtectionPoolPhase _currentPhase = poolInfo.currentPhase;
    if (
      _currentPhase == ProtectionPoolPhase.OpenToSellers &&
      _hasMinRequiredCapital()
    ) {
      poolInfo.currentPhase = _newPhase = ProtectionPoolPhase.OpenToBuyers;
      emit ProtectionPoolPhaseUpdated(_newPhase);
    } else if (_currentPhase == ProtectionPoolPhase.OpenToBuyers) {
      if (calculateLeverageRatio() <= poolInfo.params.leverageRatioCeiling) {
        poolInfo.currentPhase = _newPhase = ProtectionPoolPhase.Open;
        emit ProtectionPoolPhaseUpdated(_newPhase);
      }
    }
  }
  function getPoolInfo()
    external
    view
    override
    returns (ProtectionPoolInfo memory)
  {
    return poolInfo;
  }
  function getAllProtections()
    external
    view
    override
    returns (ProtectionInfo[] memory _protections)
  {
    uint256 _length = protectionInfos.length;
    _protections = new ProtectionInfo[](_length - 1);
    uint256 _index;
    for (uint256 i = 1; i < _length; ) {
      _protections[_index] = protectionInfos[i];
      unchecked {
        ++i;
        ++_index;
      }
    }
  }
  function calculateLeverageRatio() public view override returns (uint256) {
    return _calculateLeverageRatio(totalSTokenUnderlying);
  }
  function convertToSToken(uint256 _underlyingAmount)
    public
    view
    override
    returns (uint256)
  {
    uint256 _scaledUnderlyingAmt = ProtectionPoolHelper
      .scaleUnderlyingAmtTo18Decimals(
        _underlyingAmount,
        poolInfo.underlyingToken.decimals()
      );
    if (totalSupply() == 0) return _scaledUnderlyingAmt;
    return
      (_scaledUnderlyingAmt * Constants.SCALE_18_DECIMALS) / _getExchangeRate();
  }
  function convertToUnderlying(uint256 _sTokenShares)
    public
    view
    override
    returns (uint256)
  {
    return
      ProtectionPoolHelper.scale18DecimalsAmtToUnderlyingDecimals(
        ((_sTokenShares * _getExchangeRate()) / Constants.SCALE_18_DECIMALS), 
        poolInfo.underlyingToken.decimals()
      );
  }
  function getRequestedWithdrawalAmount(uint256 _withdrawalCycleIndex)
    external
    view
    override
    returns (uint256)
  {
    return _getRequestedWithdrawalAmount(_withdrawalCycleIndex);
  }
  function getCurrentRequestedWithdrawalAmount()
    external
    view
    override
    returns (uint256)
  {
    return
      _getRequestedWithdrawalAmount(
        poolCycleManager.getCurrentCycleIndex(address(this))
      );
  }
  function getTotalRequestedWithdrawalAmount(uint256 _withdrawalCycleIndex)
    external
    view
    override
    returns (uint256)
  {
    return withdrawalCycleDetails[_withdrawalCycleIndex].totalSTokenRequested;
  }
  function getLendingPoolDetail(address _lendingPoolAddress)
    external
    view
    override
    returns (
      uint256 _lastPremiumAccrualTimestamp,
      uint256 _totalPremium,
      uint256 _totalProtection
    )
  {
    LendingPoolDetail storage lendingPoolDetail = lendingPoolDetails[
      _lendingPoolAddress
    ];
    _lastPremiumAccrualTimestamp = lendingPoolDetail
      .lastPremiumAccrualTimestamp;
    _totalPremium = lendingPoolDetail.totalPremium;
    _totalProtection = lendingPoolDetail.totalProtection;
  }
  function getActiveProtections(address _buyer)
    external
    view
    override
    returns (ProtectionInfo[] memory _protectionInfos)
  {
    EnumerableSetUpgradeable.UintSet
      storage activeProtectionIndexes = protectionBuyerAccounts[_buyer]
        .activeProtectionIndexes;
    uint256 _length = activeProtectionIndexes.length();
    _protectionInfos = new ProtectionInfo[](_length);
    for (uint256 i; i < _length; ) {
      uint256 _protectionIndex = activeProtectionIndexes.at(i);
      _protectionInfos[i] = protectionInfos[_protectionIndex];
      unchecked {
        ++i;
      }
    }
  }
  function getTotalPremiumPaidForLendingPool(
    address _buyer,
    address _lendingPoolAddress
  ) external view override returns (uint256) {
    return
      protectionBuyerAccounts[_buyer].lendingPoolToPremium[_lendingPoolAddress];
  }
  function calculateProtectionPremium(
    ProtectionPurchaseParams calldata _protectionPurchaseParams
  )
    external
    view
    override
    returns (uint256 _premiumAmount, bool _isMinPremium)
  {
    uint256 _leverageRatio = calculateLeverageRatio();
    (, _premiumAmount, _isMinPremium) = ProtectionPoolHelper
      .calculateProtectionPremium(
        premiumCalculator,
        poolInfo,
        _protectionPurchaseParams,
        totalSTokenUnderlying,
        _leverageRatio
      );
  }
  function calculateMaxAllowedProtectionAmount(
    address _lendingPool,
    uint256 _nftLpTokenId
  ) external view override returns (uint256 _maxAllowedProtectionAmount) {
    return
      poolInfo.referenceLendingPools.calculateRemainingPrincipal(
        _lendingPool,
        msg.sender,
        _nftLpTokenId
      );
  }
  function calculateMaxAllowedProtectionDuration()
    external
    view
    override
    returns (uint256 _maxAllowedProtectionDurationInSeconds)
  {
    _maxAllowedProtectionDurationInSeconds =
      poolCycleManager.getNextCycleEndTimestamp(address(this)) -
      block.timestamp;
  }
  function getPoolDetails()
    external
    view
    override
    returns (
      uint256 _totalSTokenUnderlying,
      uint256 _totalProtection,
      uint256 _totalPremium,
      uint256 _totalPremiumAccrued
    )
  {
    _totalSTokenUnderlying = totalSTokenUnderlying;
    _totalProtection = totalProtection;
    _totalPremium = totalPremium;
    _totalPremiumAccrued = totalPremiumAccrued;
  }
  function getUnderlyingBalance(address _user)
    external
    view
    override
    returns (uint256)
  {
    return convertToUnderlying(balanceOf(_user));
  }
  function _verifyAndCreateProtection(
    uint256 _protectionStartTimestamp,
    ProtectionPurchaseParams calldata _protectionPurchaseParams,
    uint256 _maxPremiumAmount,
    bool _isRenewal
  ) internal {
    ProtectionPoolHelper.verifyProtection(
      poolCycleManager,
      defaultStateManager,
      address(this),
      poolInfo,
      _protectionStartTimestamp,
      _protectionPurchaseParams,
      _isRenewal
    );
    totalProtection += _protectionPurchaseParams.protectionAmount;
    uint256 _leverageRatio = calculateLeverageRatio();
    if (_leverageRatio < poolInfo.params.leverageRatioFloor) {
      revert ProtectionPoolLeverageRatioTooLow(_leverageRatio);
    }
    LendingPoolDetail storage lendingPoolDetail = lendingPoolDetails[
      _protectionPurchaseParams.lendingPoolAddress
    ];
    lendingPoolDetail.totalProtection += _protectionPurchaseParams
      .protectionAmount;
    (
      uint256 _premiumAmountIn18Decimals,
      uint256 _premiumAmount,
      bool _isMinPremium
    ) = ProtectionPoolHelper.calculateAndTrackPremium(
        premiumCalculator,
        protectionBuyerAccounts,
        poolInfo,
        lendingPoolDetail,
        _protectionPurchaseParams,
        _maxPremiumAmount,
        totalSTokenUnderlying,
        _leverageRatio
      );
    totalPremium += _premiumAmount;
    uint256 _protectionDurationInDaysScaled = ((
      _protectionPurchaseParams.protectionDurationInSeconds
    ) * Constants.SCALE_18_DECIMALS) / uint256(Constants.SECONDS_IN_DAY);
    console.log(
      "protectionDurationInDays: %s, protectionPremium: %s, leverageRatio: ",
      _protectionDurationInDaysScaled,
      _premiumAmount,
      _leverageRatio
    );
    (int256 _k, int256 _lambda) = AccruedPremiumCalculator.calculateKAndLambda(
      _premiumAmountIn18Decimals,
      _protectionDurationInDaysScaled,
      _leverageRatio,
      poolInfo.params.leverageRatioFloor,
      poolInfo.params.leverageRatioCeiling,
      poolInfo.params.leverageRatioBuffer,
      poolInfo.params.curvature,
      _isMinPremium ? poolInfo.params.minCarapaceRiskPremiumPercent : 0
    );
    protectionInfos.push(
      ProtectionInfo({
        buyer: msg.sender,
        protectionPremium: _premiumAmount,
        startTimestamp: _protectionStartTimestamp,
        K: _k,
        lambda: _lambda,
        expired: false,
        purchaseParams: _protectionPurchaseParams
      })
    );
    uint256 _protectionIndex = protectionInfos.length - 1;
    lendingPoolDetail.activeProtectionIndexes.add(_protectionIndex);
    protectionBuyerAccounts[msg.sender].activeProtectionIndexes.add(
      _protectionIndex
    );
    emit ProtectionBought(
      msg.sender,
      _protectionPurchaseParams.lendingPoolAddress,
      _protectionPurchaseParams.protectionAmount,
      _premiumAmount
    );
    poolInfo.underlyingToken.safeTransferFrom(
      msg.sender,
      address(this),
      _premiumAmount
    );
  }
  function _getExchangeRate() internal view returns (uint256) {
    uint256 _totalScaledCapital = ProtectionPoolHelper
      .scaleUnderlyingAmtTo18Decimals(
        totalSTokenUnderlying,
        poolInfo.underlyingToken.decimals()
      );
    uint256 _totalSTokenSupply = totalSupply();
    uint256 _exchangeRate = (_totalScaledCapital *
      Constants.SCALE_18_DECIMALS) / _totalSTokenSupply;
    console.log(
      "Total capital: %s, Total SToken Supply: %s, exchange rate: %s",
      _totalScaledCapital,
      _totalSTokenSupply,
      _exchangeRate
    );
    return _exchangeRate;
  }
  function _hasMinRequiredCapital() internal view returns (bool) {
    return totalSTokenUnderlying >= poolInfo.params.minRequiredCapital;
  }
  function _calculateLeverageRatio(uint256 _totalCapital)
    internal
    view
    returns (uint256)
  {
    if (totalProtection == 0) {
      return 0;
    }
    return (_totalCapital * Constants.SCALE_18_DECIMALS) / totalProtection;
  }
  function _accruePremiumAndExpireProtections(
    LendingPoolDetail storage lendingPoolDetail,
    uint256 _lastPremiumAccrualTimestamp,
    uint256 _latestPaymentTimestamp
  )
    internal
    returns (
      uint256 _accruedPremiumForLendingPool,
      uint256 _totalProtectionRemoved
    )
  {
    uint256[] memory _protectionIndexes = lendingPoolDetail
      .activeProtectionIndexes
      .values();
    uint256 _length = _protectionIndexes.length;
    for (uint256 j; j < _length; ) {
      uint256 _protectionIndex = _protectionIndexes[j];
      ProtectionInfo storage protectionInfo = protectionInfos[_protectionIndex];
      (
        uint256 _accruedPremiumInUnderlying,
        bool _expired
      ) = ProtectionPoolHelper.verifyAndAccruePremium(
          poolInfo,
          protectionInfo,
          _lastPremiumAccrualTimestamp,
          _latestPaymentTimestamp
        );
      _accruedPremiumForLendingPool += _accruedPremiumInUnderlying;
      if (_expired) {
        _totalProtectionRemoved += protectionInfo
          .purchaseParams
          .protectionAmount;
        ProtectionPoolHelper.expireProtection(
          protectionBuyerAccounts,
          protectionInfo,
          lendingPoolDetail,
          _protectionIndex
        );
        emit ProtectionExpired(
          protectionInfo.buyer,
          protectionInfo.purchaseParams.lendingPoolAddress,
          protectionInfo.purchaseParams.protectionAmount
        );
      }
      unchecked {
        ++j;
      }
    }
  }
  function _deposit(uint256 _underlyingAmount, address _receiver) internal {
    if (poolInfo.currentPhase == ProtectionPoolPhase.OpenToBuyers) {
      revert ProtectionPoolInOpenToBuyersPhase();
    }
    uint256 _sTokenShares = convertToSToken(_underlyingAmount);
    totalSTokenUnderlying += _underlyingAmount;
    _safeMint(_receiver, _sTokenShares);
    poolInfo.underlyingToken.safeTransferFrom(
      msg.sender,
      address(this),
      _underlyingAmount
    );
    if (_hasMinRequiredCapital()) {
      uint256 _leverageRatio = calculateLeverageRatio();
      if (_leverageRatio > poolInfo.params.leverageRatioCeiling) {
        revert ProtectionPoolLeverageRatioTooHigh(_leverageRatio);
      }
    }
    emit ProtectionSold(_receiver, _underlyingAmount);
  }
  function _requestWithdrawal(uint256 _sTokenAmount) internal {
    uint256 _sTokenBalance = balanceOf(msg.sender);
    if (_sTokenAmount > _sTokenBalance) {
      revert InsufficientSTokenBalance(msg.sender, _sTokenBalance);
    }
    uint256 _currentCycleIndex = poolCycleManager.getCurrentCycleIndex(
      address(this)
    );
    uint256 _withdrawalCycleIndex = _currentCycleIndex + 2;
    WithdrawalCycleDetail storage withdrawalCycle = withdrawalCycleDetails[
      _withdrawalCycleIndex
    ];
    uint256 _oldRequestAmount = withdrawalCycle.withdrawalRequests[msg.sender];
    withdrawalCycle.withdrawalRequests[msg.sender] = _sTokenAmount;
    unchecked {
      if (_oldRequestAmount > _sTokenAmount) {
        withdrawalCycle.totalSTokenRequested -= (_oldRequestAmount -
          _sTokenAmount);
      } else {
        withdrawalCycle.totalSTokenRequested += (_sTokenAmount -
          _oldRequestAmount);
      }
    }
    emit WithdrawalRequested(msg.sender, _sTokenAmount, _withdrawalCycleIndex);
  }
  function _getRequestedWithdrawalAmount(uint256 _withdrawalCycleIndex)
    internal
    view
    returns (uint256)
  {
    return
      withdrawalCycleDetails[_withdrawalCycleIndex].withdrawalRequests[
        msg.sender
      ];
  }
}