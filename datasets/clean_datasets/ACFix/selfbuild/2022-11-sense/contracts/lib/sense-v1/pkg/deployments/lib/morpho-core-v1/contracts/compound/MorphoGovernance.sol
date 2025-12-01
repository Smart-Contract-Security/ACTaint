pragma solidity 0.8.13;
import "./MorphoUtils.sol";
abstract contract MorphoGovernance is MorphoUtils {
    using SafeTransferLib for ERC20;
    event DefaultMaxGasForMatchingSet(Types.MaxGasForMatching _defaultMaxGasForMatching);
    event MaxSortedUsersSet(uint256 _newValue);
    event TreasuryVaultSet(address indexed _newTreasuryVaultAddress);
    event IncentivesVaultSet(address indexed _newIncentivesVaultAddress);
    event PositionsManagerSet(address indexed _positionsManager);
    event RewardsManagerSet(address indexed _newRewardsManagerAddress);
    event InterestRatesSet(address indexed _interestRatesManager);
    event DustThresholdSet(uint256 _dustThreshold);
    event ReserveFactorSet(address indexed _poolTokenAddress, uint16 _newValue);
    event P2PIndexCursorSet(address indexed _poolTokenAddress, uint16 _newValue);
    event ReserveFeeClaimed(address indexed _poolTokenAddress, uint256 _amountClaimed);
    event P2PStatusSet(address indexed _poolTokenAddress, bool _p2pDisabled);
    event PauseStatusSet(address indexed _poolTokenAddress, bool _newStatus);
    event PartialPauseStatusSet(address indexed _poolTokenAddress, bool _newStatus);
    event ClaimRewardsPauseStatusSet(bool _newStatus);
    event MarketCreated(
        address indexed _poolTokenAddress,
        uint16 _reserveFactor,
        uint16 _p2pIndexCursor
    );
    error MarketCreationFailedOnCompound();
    error ExceedsMaxBasisPoints();
    error MarketAlreadyCreated();
    error AmountIsZero();
    error ZeroAddress();
    function initialize(
        IPositionsManager _positionsManager,
        IInterestRatesManager _interestRatesManager,
        IComptroller _comptroller,
        Types.MaxGasForMatching memory _defaultMaxGasForMatching,
        uint256 _dustThreshold,
        uint256 _maxSortedUsers,
        address _cEth,
        address _wEth
    ) external initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        interestRatesManager = _interestRatesManager;
        positionsManager = _positionsManager;
        comptroller = _comptroller;
        defaultMaxGasForMatching = _defaultMaxGasForMatching;
        dustThreshold = _dustThreshold;
        maxSortedUsers = _maxSortedUsers;
        cEth = _cEth;
        wEth = _wEth;
    }
    function setMaxSortedUsers(uint256 _newMaxSortedUsers) external onlyOwner {
        maxSortedUsers = _newMaxSortedUsers;
        emit MaxSortedUsersSet(_newMaxSortedUsers);
    }
    function setDefaultMaxGasForMatching(Types.MaxGasForMatching memory _defaultMaxGasForMatching)
        external
        onlyOwner
    {
        defaultMaxGasForMatching = _defaultMaxGasForMatching;
        emit DefaultMaxGasForMatchingSet(_defaultMaxGasForMatching);
    }
    function setPositionsManager(IPositionsManager _positionsManager) external onlyOwner {
        positionsManager = _positionsManager;
        emit PositionsManagerSet(address(_positionsManager));
    }
    function setRewardsManager(IRewardsManager _rewardsManager) external onlyOwner {
        rewardsManager = _rewardsManager;
        emit RewardsManagerSet(address(_rewardsManager));
    }
    function setInterestRatesManager(IInterestRatesManager _interestRatesManager)
        external
        onlyOwner
    {
        interestRatesManager = _interestRatesManager;
        emit InterestRatesSet(address(_interestRatesManager));
    }
    function setTreasuryVault(address _treasuryVault) external onlyOwner {
        treasuryVault = _treasuryVault;
        emit TreasuryVaultSet(_treasuryVault);
    }
    function setIncentivesVault(IIncentivesVault _incentivesVault) external onlyOwner {
        incentivesVault = _incentivesVault;
        emit IncentivesVaultSet(address(_incentivesVault));
    }
    function setDustThreshold(uint256 _dustThreshold) external onlyOwner {
        dustThreshold = _dustThreshold;
        emit DustThresholdSet(_dustThreshold);
    }
    function setReserveFactor(address _poolTokenAddress, uint16 _newReserveFactor)
        external
        onlyOwner
        isMarketCreated(_poolTokenAddress)
    {
        if (_newReserveFactor > MAX_BASIS_POINTS) revert ExceedsMaxBasisPoints();
        _updateP2PIndexes(_poolTokenAddress);
        marketParameters[_poolTokenAddress].reserveFactor = _newReserveFactor;
        emit ReserveFactorSet(_poolTokenAddress, _newReserveFactor);
    }
    function setP2PIndexCursor(address _poolTokenAddress, uint16 _p2pIndexCursor)
        external
        onlyOwner
        isMarketCreated(_poolTokenAddress)
    {
        if (_p2pIndexCursor > MAX_BASIS_POINTS) revert ExceedsMaxBasisPoints();
        _updateP2PIndexes(_poolTokenAddress);
        marketParameters[_poolTokenAddress].p2pIndexCursor = _p2pIndexCursor;
        emit P2PIndexCursorSet(_poolTokenAddress, _p2pIndexCursor);
    }
    function setPauseStatus(address _poolTokenAddress, bool _newStatus)
        external
        onlyOwner
        isMarketCreated(_poolTokenAddress)
    {
        marketStatus[_poolTokenAddress].isPaused = _newStatus;
        emit PauseStatusSet(_poolTokenAddress, _newStatus);
    }
    function setPartialPauseStatus(address _poolTokenAddress, bool _newStatus)
        external
        onlyOwner
        isMarketCreated(_poolTokenAddress)
    {
        marketStatus[_poolTokenAddress].isPartiallyPaused = _newStatus;
        emit PartialPauseStatusSet(_poolTokenAddress, _newStatus);
    }
    function setP2PDisabled(address _poolTokenAddress, bool _newStatus)
        external
        onlyOwner
        isMarketCreated(_poolTokenAddress)
    {
        p2pDisabled[_poolTokenAddress] = _newStatus;
        emit P2PStatusSet(_poolTokenAddress, _newStatus);
    }
    function setClaimRewardsPauseStatus(bool _newStatus) external onlyOwner {
        isClaimRewardsPaused = _newStatus;
        emit ClaimRewardsPauseStatusSet(_newStatus);
    }
    function claimToTreasury(address[] calldata _poolTokenAddresses, uint256[] calldata _amounts)
        external
        onlyOwner
    {
        if (treasuryVault == address(0)) revert ZeroAddress();
        uint256 numberOfMarkets = _poolTokenAddresses.length;
        for (uint256 i; i < numberOfMarkets; ++i) {
            address poolTokenAddress = _poolTokenAddresses[i];
            Types.MarketStatus memory status = marketStatus[poolTokenAddress];
            if (!status.isCreated || status.isPaused || status.isPartiallyPaused) continue;
            ERC20 underlyingToken = _getUnderlying(poolTokenAddress);
            uint256 underlyingBalance = underlyingToken.balanceOf(address(this));
            if (underlyingBalance == 0) continue;
            uint256 toClaim = Math.min(_amounts[i], underlyingBalance);
            underlyingToken.safeTransfer(treasuryVault, toClaim);
            emit ReserveFeeClaimed(poolTokenAddress, toClaim);
        }
    }
    function createMarket(address _poolTokenAddress, Types.MarketParameters calldata _marketParams)
        external
        onlyOwner
    {
        if (
            _marketParams.p2pIndexCursor > MAX_BASIS_POINTS ||
            _marketParams.reserveFactor > MAX_BASIS_POINTS
        ) revert ExceedsMaxBasisPoints();
        if (marketStatus[_poolTokenAddress].isCreated) revert MarketAlreadyCreated();
        marketStatus[_poolTokenAddress].isCreated = true;
        address[] memory marketToEnter = new address[](1);
        marketToEnter[0] = _poolTokenAddress;
        uint256[] memory results = comptroller.enterMarkets(marketToEnter);
        if (results[0] != 0) revert MarketCreationFailedOnCompound();
        ICToken poolToken = ICToken(_poolTokenAddress);
        uint256 initialIndex;
        if (_poolTokenAddress == cEth) initialIndex = 2e26;
        else initialIndex = 2 * 10**(16 + ERC20(poolToken.underlying()).decimals() - 8);
        p2pSupplyIndex[_poolTokenAddress] = initialIndex;
        p2pBorrowIndex[_poolTokenAddress] = initialIndex;
        Types.LastPoolIndexes storage poolIndexes = lastPoolIndexes[_poolTokenAddress];
        poolIndexes.lastUpdateBlockNumber = uint32(block.number);
        poolIndexes.lastSupplyPoolIndex = uint112(poolToken.exchangeRateCurrent());
        poolIndexes.lastBorrowPoolIndex = uint112(poolToken.borrowIndex());
        marketParameters[_poolTokenAddress] = _marketParams;
        marketsCreated.push(_poolTokenAddress);
        emit MarketCreated(
            _poolTokenAddress,
            _marketParams.reserveFactor,
            _marketParams.p2pIndexCursor
        );
    }
}