pragma solidity ^0.8.11;
import "./Vault.sol";
import "./Interfaces/IXProvider.sol";
contract MainVault is Vault, VaultToken {
  using SafeERC20 for IERC20;
  struct UserInfo {
    uint256 withdrawalAllowance;
    uint256 withdrawalRequestPeriod;
    uint256 rewardAllowance;
    uint256 rewardRequestPeriod;
  }
  address public derbyToken;
  address public game;
  address public xProvider;
  bool public vaultOff;
  bool public swapRewards;
  uint256 internal totalWithdrawalRequests;
  uint256 public exchangeRate;
  uint32 public homeChain;
  uint256 public amountToSendXChain;
  uint256 public governanceFee; 
  uint256 public maxDivergenceWithdraws;
  string internal allowanceError = "!Allowance";
  mapping(address => UserInfo) internal userInfo;
  bool private training;
  uint256 private maxTrainingDeposit;
  mapping(address => bool) private whitelist;
  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    uint256 _vaultNumber,
    address _dao,
    address _game,
    address _controller,
    address _vaultCurrency,
    uint256 _uScale
  )
    VaultToken(_name, _symbol, _decimals)
    Vault(_vaultNumber, _dao, _controller, _vaultCurrency, _uScale)
  {
    exchangeRate = _uScale;
    game = _game;
    governanceFee = 0;
    maxDivergenceWithdraws = 1_000_000;
  }
  modifier onlyXProvider() {
    require(msg.sender == xProvider, "only xProvider");
    _;
  }
  modifier onlyWhenVaultIsOn() {
    require(state == State.Idle, "Rebalancing");
    require(!vaultOff, "Vault is off");
    _;
  }
  modifier onlyWhenIdle() {
    require(state == State.Idle, "Rebalancing");
    _;
  }
  modifier onlyGame() {
    require(msg.sender == game, "only game");
    _;
  }
  event PushTotalUnderlying(
    uint256 _vaultNumber,
    uint32 _chainId,
    uint256 _underlying,
    uint256 _totalSupply,
    uint256 _withdrawalRequests
  );
  event RebalanceXChain(uint256 _vaultNumber, uint256 _amount, address _asset);
  event PushedRewardsToGame(uint256 _vaultNumber, uint32 _chain, int256[] _rewards);
  function deposit(
    uint256 _amount,
    address _receiver
  ) external nonReentrant onlyWhenVaultIsOn returns (uint256 shares) {
    if (training) {
      require(whitelist[msg.sender]);
      uint256 balanceSender = (balanceOf(msg.sender) * exchangeRate) / (10 ** decimals());
      require(_amount + balanceSender <= maxTrainingDeposit);
    }
    uint256 balanceBefore = getVaultBalance() - reservedFunds;
    vaultCurrency.safeTransferFrom(msg.sender, address(this), _amount);
    uint256 balanceAfter = getVaultBalance() - reservedFunds;
    uint256 amount = balanceAfter - balanceBefore;
    shares = (amount * (10 ** decimals())) / exchangeRate;
    _mint(_receiver, shares);
  }
  function withdraw(
    uint256 _amount,
    address _receiver,
    address _owner
  ) external nonReentrant onlyWhenVaultIsOn returns (uint256 value) {
    value = (_amount * exchangeRate) / (10 ** decimals());
    require(value > 0, "!value");
    require(getVaultBalance() - reservedFunds >= value, "!funds");
    _burn(msg.sender, _amount);
    transferFunds(_receiver, value);
  }
  function withdrawalRequest(
    uint256 _amount
  ) external nonReentrant onlyWhenVaultIsOn returns (uint256 value) {
    UserInfo storage user = userInfo[msg.sender];
    require(user.withdrawalRequestPeriod == 0, "Already a request");
    value = (_amount * exchangeRate) / (10 ** decimals());
    _burn(msg.sender, _amount);
    user.withdrawalAllowance = value;
    user.withdrawalRequestPeriod = rebalancingPeriod;
    totalWithdrawalRequests += value;
  }
  function withdrawAllowance() external nonReentrant onlyWhenIdle returns (uint256 value) {
    UserInfo storage user = userInfo[msg.sender];
    require(user.withdrawalAllowance > 0, allowanceError);
    require(rebalancingPeriod > user.withdrawalRequestPeriod, "Funds not arrived");
    value = user.withdrawalAllowance;
    value = checkForBalance(value);
    reservedFunds -= value;
    delete user.withdrawalAllowance;
    delete user.withdrawalRequestPeriod;
    transferFunds(msg.sender, value);
  }
  function transferFunds(address _receiver, uint256 _value) internal {
    uint256 govFee = (_value * governanceFee) / 10_000;
    vaultCurrency.safeTransfer(getDao(), govFee);
    vaultCurrency.safeTransfer(_receiver, _value - govFee);
  }
  function redeemRewardsGame(
    uint256 _value,
    address _user
  ) external onlyGame nonReentrant onlyWhenVaultIsOn {
    UserInfo storage user = userInfo[_user];
    require(user.rewardAllowance == 0, allowanceError);
    user.rewardAllowance = _value;
    user.rewardRequestPeriod = rebalancingPeriod;
    totalWithdrawalRequests += _value;
  }
  function withdrawRewards() external nonReentrant onlyWhenIdle returns (uint256 value) {
    UserInfo storage user = userInfo[msg.sender];
    require(user.rewardAllowance > 0, allowanceError);
    require(rebalancingPeriod > user.rewardRequestPeriod, "!Funds");
    value = user.rewardAllowance;
    value = checkForBalance(value);
    reservedFunds -= value;
    delete user.rewardAllowance;
    delete user.rewardRequestPeriod;
    if (swapRewards) {
      uint256 tokensReceived = Swap.swapTokensMulti(
        Swap.SwapInOut(value, address(vaultCurrency), derbyToken),
        controller.getUniswapParams(),
        true
      );
      IERC20(derbyToken).safeTransfer(msg.sender, tokensReceived);
    } else {
      vaultCurrency.safeTransfer(msg.sender, value);
    }
  }
  function checkForBalance(uint256 _value) internal view returns (uint256) {
    if (_value > getVaultBalance()) {
      uint256 oldValue = _value;
      _value = getVaultBalance();
      require(oldValue - _value <= maxDivergenceWithdraws, "Max divergence");
    }
    return _value;
  }
  function pushTotalUnderlyingToController() external payable onlyWhenIdle {
    require(rebalanceNeeded(), "!rebalance needed");
    setTotalUnderlying();
    uint256 underlying = savedTotalUnderlying + getVaultBalance() - reservedFunds;
    IXProvider(xProvider).pushTotalUnderlying{value: msg.value}(
      vaultNumber,
      homeChain,
      underlying,
      totalSupply(),
      totalWithdrawalRequests
    );
    state = State.PushedUnderlying;
    lastTimeStamp = block.timestamp;
    emit PushTotalUnderlying(
      vaultNumber,
      homeChain,
      underlying,
      totalSupply(),
      totalWithdrawalRequests
    );
  }
  function setXChainAllocation(
    uint256 _amountToSend,
    uint256 _exchangeRate,
    bool _receivingFunds
  ) external onlyXProvider {
    require(state == State.PushedUnderlying, stateError);
    setXChainAllocationInt(_amountToSend, _exchangeRate, _receivingFunds);
  }
  function setXChainAllocationInt(
    uint256 _amountToSend,
    uint256 _exchangeRate,
    bool _receivingFunds
  ) internal {
    amountToSendXChain = _amountToSend;
    exchangeRate = _exchangeRate;
    if (_amountToSend == 0 && !_receivingFunds) settleReservedFunds();
    else if (_amountToSend == 0 && _receivingFunds) state = State.WaitingForFunds;
    else state = State.SendingFundsXChain;
  }
  function rebalanceXChain(uint256 _slippage, uint256 _relayerFee) external payable {
    require(state == State.SendingFundsXChain, stateError);
    if (amountToSendXChain > getVaultBalance()) pullFunds(amountToSendXChain);
    if (amountToSendXChain > getVaultBalance()) amountToSendXChain = getVaultBalance();
    vaultCurrency.safeIncreaseAllowance(xProvider, amountToSendXChain);
    IXProvider(xProvider).xTransferToController{value: msg.value}(
      vaultNumber,
      amountToSendXChain,
      address(vaultCurrency),
      _slippage,
      _relayerFee
    );
    emit RebalanceXChain(vaultNumber, amountToSendXChain, address(vaultCurrency));
    amountToSendXChain = 0;
    settleReservedFunds();
  }
  function receiveFunds() external onlyXProvider {
    if (state != State.WaitingForFunds) return;
    settleReservedFunds();
  }
  function settleReservedFunds() internal {
    reservedFunds += totalWithdrawalRequests;
    totalWithdrawalRequests = 0;
    state = State.RebalanceVault;
  }
  function receiveProtocolAllocations(int256[] memory _deltas) external onlyXProvider {
    receiveProtocolAllocationsInt(_deltas);
  }
  function receiveProtocolAllocationsInt(int256[] memory _deltas) internal {
    for (uint i = 0; i < _deltas.length; i++) {
      int256 allocation = _deltas[i];
      if (allocation == 0) continue;
      setDeltaAllocationsInt(i, allocation);
    }
    deltaAllocationsReceived = true;
  }
  function sendRewardsToGame() external payable {
    require(state == State.SendRewardsPerToken, stateError);
    int256[] memory rewards = rewardsToArray();
    IXProvider(xProvider).pushRewardsToGame{value: msg.value}(vaultNumber, homeChain, rewards);
    state = State.Idle;
    emit PushedRewardsToGame(vaultNumber, homeChain, rewards);
  }
  function toggleVaultOnOff(bool _state) external onlyXProvider {
    vaultOff = _state;
  }
  function getWithdrawalAllowance() external view returns (uint256) {
    return userInfo[msg.sender].withdrawalAllowance;
  }
  function getRewardAllowance() external view returns (uint256) {
    return userInfo[msg.sender].rewardAllowance;
  }
  function setHomeXProvider(address _xProvider) external onlyDao {
    xProvider = _xProvider;
  }
  function setDaoToken(address _token) external onlyDao {
    derbyToken = _token;
  }
  function setGame(address _game) external onlyDao {
    game = _game;
  }
  function setSwapRewards(bool _state) external onlyDao {
    swapRewards = _state;
  }
  function setMaxDivergence(uint256 _maxDivergence) external onlyDao {
    maxDivergenceWithdraws = _maxDivergence;
  }
  function setXChainAllocationGuard(
    uint256 _amountToSend,
    uint256 _exchangeRate,
    bool _receivingFunds
  ) external onlyGuardian {
    setXChainAllocationInt(_amountToSend, _exchangeRate, _receivingFunds);
  }
  function receiveFundsGuard() external onlyGuardian {
    settleReservedFunds();
  }
  function receiveProtocolAllocationsGuard(int256[] memory _deltas) external onlyGuardian {
    receiveProtocolAllocationsInt(_deltas);
  }
  function setVaultStateGuard(State _state) external onlyGuardian {
    state = _state;
  }
  function setHomeChain(uint32 _homeChain) external onlyGuardian {
    homeChain = _homeChain;
  }
  function setGovernanceFee(uint16 _fee) external onlyGuardian {
    governanceFee = _fee;
  }
  function setTraining(bool _state) external onlyGuardian {
    training = _state;
  }
  function setTrainingDeposit(uint256 _maxDeposit) external onlyGuardian {
    maxTrainingDeposit = _maxDeposit;
  }
  function addToWhitelist(address _address) external onlyGuardian {
    whitelist[_address] = true;
  }
}