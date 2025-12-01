pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Interfaces/IController.sol";
import "./Interfaces/IProvider.sol";
import "./VaultToken.sol";
import "./libraries/Swap.sol";
contract Vault is ReentrancyGuard {
  using SafeERC20 for IERC20;
  enum State {
    Idle,
    PushedUnderlying,
    SendingFundsXChain,
    WaitingForFunds,
    RebalanceVault,
    SendRewardsPerToken
  }
  IERC20 internal vaultCurrency;
  IController internal controller;
  State public state;
  bool public deltaAllocationsReceived;
  address private dao;
  address private guardian;
  address public vaultCurrencyAddr;
  address public xController;
  uint256 public vaultNumber;
  uint256 public liquidityPerc;
  uint256 public performanceFee;
  uint256 public rebalancingPeriod;
  uint256 public uScale;
  uint256 public minimumPull;
  int256 public marginScale;
  uint256 public rebalanceInterval;
  uint256 public lastTimeStamp;
  uint256 public savedTotalUnderlying;
  uint256 internal reservedFunds;
  int256 public totalAllocatedTokens;
  int256 private deltaAllocatedTokens;
  string internal stateError = "Wrong state";
  mapping(uint256 => int256) internal currentAllocations;
  mapping(uint256 => int256) internal deltaAllocations;
  mapping(uint256 => mapping(uint256 => int256)) public rewardPerLockedToken;
  mapping(uint256 => uint256) public lastPrices;
  modifier onlyDao() {
    require(msg.sender == dao, "Vault: only DAO");
    _;
  }
  modifier onlyGuardian() {
    require(msg.sender == guardian, "only Guardian");
    _;
  }
  constructor(
    uint256 _vaultNumber,
    address _dao,
    address _controller,
    address _vaultCurrency,
    uint256 _uScale
  ) {
    controller = IController(_controller);
    vaultCurrency = IERC20(_vaultCurrency);
    vaultNumber = _vaultNumber;
    dao = _dao;
    uScale = _uScale;
    lastTimeStamp = block.timestamp;
    minimumPull = 1_000_000;
  }
  function pullFunds(uint256 _value) internal {
    uint256 latestID = controller.latestProtocolId(vaultNumber);
    for (uint i = 0; i < latestID; i++) {
      if (currentAllocations[i] == 0) continue;
      uint256 shortage = _value - vaultCurrency.balanceOf(address(this));
      uint256 balanceProtocol = balanceUnderlying(i);
      uint256 amountToWithdraw = shortage > balanceProtocol ? balanceProtocol : shortage;
      savedTotalUnderlying -= amountToWithdraw;
      if (amountToWithdraw < minimumPull) break;
      withdrawFromProtocol(i, amountToWithdraw);
      if (_value <= vaultCurrency.balanceOf(address(this))) break;
    }
  }
  function rebalance() external nonReentrant {
    require(state == State.RebalanceVault, stateError);
    require(deltaAllocationsReceived, "!Delta allocations");
    rebalancingPeriod++;
    claimTokens();
    settleDeltaAllocation();
    uint256 underlyingIncBalance = calcUnderlyingIncBalance();
    uint256[] memory protocolToDeposit = rebalanceCheckProtocols(underlyingIncBalance);
    executeDeposits(protocolToDeposit);
    setTotalUnderlying();
    if (reservedFunds > vaultCurrency.balanceOf(address(this))) pullFunds(reservedFunds);
    state = State.SendRewardsPerToken;
    deltaAllocationsReceived = false;
  }
  function calcUnderlyingIncBalance() internal view returns (uint256) {
    uint256 totalUnderlyingInclVaultBalance = savedTotalUnderlying +
      getVaultBalance() -
      reservedFunds;
    uint256 liquidityVault = (totalUnderlyingInclVaultBalance * liquidityPerc) / 100;
    return totalUnderlyingInclVaultBalance - liquidityVault;
  }
  function settleDeltaAllocation() internal {
    totalAllocatedTokens += deltaAllocatedTokens;
    deltaAllocatedTokens = 0;
  }
  function rebalanceCheckProtocols(
    uint256 _newTotalUnderlying
  ) internal returns (uint256[] memory) {
    uint256[] memory protocolToDeposit = new uint[](controller.latestProtocolId(vaultNumber));
    uint256 latestID = controller.latestProtocolId(vaultNumber);
    for (uint i = 0; i < latestID; i++) {
      bool isBlacklisted = controller.getProtocolBlacklist(vaultNumber, i);
      storePriceAndRewards(_newTotalUnderlying, i);
      if (isBlacklisted) continue;
      setAllocation(i);
      int256 amountToProtocol = calcAmountToProtocol(_newTotalUnderlying, i);
      uint256 currentBalance = balanceUnderlying(i);
      int256 amountToDeposit = amountToProtocol - int(currentBalance);
      uint256 amountToWithdraw = amountToDeposit < 0 ? currentBalance - uint(amountToProtocol) : 0;
      if (amountToDeposit > marginScale) protocolToDeposit[i] = uint256(amountToDeposit);
      if (amountToWithdraw > uint(marginScale) || currentAllocations[i] == 0)
        withdrawFromProtocol(i, amountToWithdraw);
    }
    return protocolToDeposit;
  }
  function calcAmountToProtocol(
    uint256 _totalUnderlying,
    uint256 _protocol
  ) internal view returns (int256 amountToProtocol) {
    if (totalAllocatedTokens == 0) amountToProtocol = 0;
    else
      amountToProtocol =
        (int(_totalUnderlying) * currentAllocations[_protocol]) /
        totalAllocatedTokens;
  }
  function storePriceAndRewards(uint256 _totalUnderlying, uint256 _protocolId) internal {
    uint256 currentPrice = price(_protocolId);
    if (lastPrices[_protocolId] == 0) {
      lastPrices[_protocolId] = currentPrice;
      return;
    }
    int256 priceDiff = int256(currentPrice - lastPrices[_protocolId]);
    int256 nominator = (int256(_totalUnderlying * performanceFee) * priceDiff);
    int256 totalAllocatedTokensRounded = totalAllocatedTokens / 1E18;
    int256 denominator = totalAllocatedTokensRounded * int256(lastPrices[_protocolId]) * 100; 
    if (totalAllocatedTokensRounded == 0) {
      rewardPerLockedToken[rebalancingPeriod][_protocolId] = 0;
    } else {
      rewardPerLockedToken[rebalancingPeriod][_protocolId] = nominator / denominator;
    }
    lastPrices[_protocolId] = currentPrice;
  }
  function rewardsToArray() internal view returns (int256[] memory rewards) {
    uint256 latestId = controller.latestProtocolId(vaultNumber);
    rewards = new int[](latestId);
    for (uint256 i = 0; i < latestId; i++) {
      rewards[i] = rewardPerLockedToken[rebalancingPeriod][i];
    }
  }
  function setAllocation(uint256 _i) internal {
    currentAllocations[_i] += deltaAllocations[_i];
    deltaAllocations[_i] = 0;
    require(currentAllocations[_i] >= 0, "Allocation underflow");
  }
  function executeDeposits(uint256[] memory protocolToDeposit) internal {
    uint256 latestID = controller.latestProtocolId(vaultNumber);
    for (uint i = 0; i < latestID; i++) {
      uint256 amount = protocolToDeposit[i];
      if (amount == 0) continue;
      depositInProtocol(i, amount);
    }
  }
  function depositInProtocol(uint256 _protocolNum, uint256 _amount) internal {
    IController.ProtocolInfoS memory protocol = controller.getProtocolInfo(
      vaultNumber,
      _protocolNum
    );
    if (getVaultBalance() < _amount) _amount = getVaultBalance();
    if (protocol.underlying != address(vaultCurrency)) {
      _amount = Swap.swapStableCoins(
        Swap.SwapInOut(_amount, address(vaultCurrency), protocol.underlying),
        uScale,
        controller.underlyingUScale(protocol.underlying),
        controller.getCurveParams(address(vaultCurrency), protocol.underlying)
      );
    }
    IERC20(protocol.underlying).safeIncreaseAllowance(protocol.provider, _amount);
    IProvider(protocol.provider).deposit(_amount, protocol.LPToken, protocol.underlying);
  }
  function withdrawFromProtocol(uint256 _protocolNum, uint256 _amount) internal {
    if (_amount <= 0) return;
    IController.ProtocolInfoS memory protocol = controller.getProtocolInfo(
      vaultNumber,
      _protocolNum
    );
    _amount = (_amount * protocol.uScale) / uScale;
    uint256 shares = IProvider(protocol.provider).calcShares(_amount, protocol.LPToken);
    uint256 balance = IProvider(protocol.provider).balance(address(this), protocol.LPToken);
    if (shares == 0) return;
    if (balance < shares) shares = balance;
    IERC20(protocol.LPToken).safeIncreaseAllowance(protocol.provider, shares);
    uint256 amountReceived = IProvider(protocol.provider).withdraw(
      shares,
      protocol.LPToken,
      protocol.underlying
    );
    if (protocol.underlying != address(vaultCurrency)) {
      _amount = Swap.swapStableCoins(
        Swap.SwapInOut(amountReceived, protocol.underlying, address(vaultCurrency)),
        controller.underlyingUScale(protocol.underlying),
        uScale,
        controller.getCurveParams(protocol.underlying, address(vaultCurrency))
      );
    }
  }
  function setTotalUnderlying() public {
    uint totalUnderlying;
    uint256 latestID = controller.latestProtocolId(vaultNumber);
    for (uint i = 0; i < latestID; i++) {
      if (currentAllocations[i] == 0) continue;
      totalUnderlying += balanceUnderlying(i);
    }
    savedTotalUnderlying = totalUnderlying;
  }
  function balanceUnderlying(uint256 _protocolNum) public view returns (uint256) {
    IController.ProtocolInfoS memory protocol = controller.getProtocolInfo(
      vaultNumber,
      _protocolNum
    );
    uint256 underlyingBalance = (IProvider(protocol.provider).balanceUnderlying(
      address(this),
      protocol.LPToken
    ) * uScale) / protocol.uScale;
    return underlyingBalance;
  }
  function calcShares(uint256 _protocolNum, uint256 _amount) public view returns (uint256) {
    IController.ProtocolInfoS memory protocol = controller.getProtocolInfo(
      vaultNumber,
      _protocolNum
    );
    uint256 shares = IProvider(protocol.provider).calcShares(
      (_amount * protocol.uScale) / uScale,
      protocol.LPToken
    );
    return shares;
  }
  function price(uint256 _protocolNum) public view returns (uint256) {
    IController.ProtocolInfoS memory protocol = controller.getProtocolInfo(
      vaultNumber,
      _protocolNum
    );
    return IProvider(protocol.provider).exchangeRate(protocol.LPToken);
  }
  function setDeltaAllocationsInt(uint256 _protocolNum, int256 _allocation) internal {
    require(!controller.getProtocolBlacklist(vaultNumber, _protocolNum), "Protocol on blacklist");
    deltaAllocations[_protocolNum] += _allocation;
    deltaAllocatedTokens += _allocation;
  }
  function claimTokens() public {
    uint256 latestID = controller.latestProtocolId(vaultNumber);
    for (uint i = 0; i < latestID; i++) {
      if (currentAllocations[i] == 0) continue;
      bool claim = controller.claim(vaultNumber, i);
      if (claim) {
        address govToken = controller.getGovToken(vaultNumber, i);
        uint256 tokenBalance = IERC20(govToken).balanceOf(address(this));
        Swap.swapTokensMulti(
          Swap.SwapInOut(tokenBalance, govToken, address(vaultCurrency)),
          controller.getUniswapParams(),
          false
        );
      }
    }
  }
  function getVaultBalance() public view returns (uint256) {
    return vaultCurrency.balanceOf(address(this));
  }
  function rebalanceNeeded() public view returns (bool) {
    return (block.timestamp - lastTimeStamp) > rebalanceInterval || msg.sender == guardian;
  }
  function getDao() public view returns (address) {
    return dao;
  }
  function getGuardian() public view returns (address) {
    return guardian;
  }
  function setPerformanceFee(uint256 _performanceFee) external onlyDao {
    require(_performanceFee <= 100);
    performanceFee = _performanceFee;
  }
  function setDao(address _dao) external onlyDao {
    dao = _dao;
  }
  function setGuardian(address _guardian) external onlyDao {
    guardian = _guardian;
  }
  function setRebalanceInterval(uint256 _timestampInternal) external onlyGuardian {
    rebalanceInterval = _timestampInternal;
  }
  function blacklistProtocol(uint256 _protocolNum) external onlyGuardian {
    uint256 balanceProtocol = balanceUnderlying(_protocolNum);
    currentAllocations[_protocolNum] = 0;
    controller.setProtocolBlacklist(vaultNumber, _protocolNum);
    savedTotalUnderlying -= balanceProtocol;
    withdrawFromProtocol(_protocolNum, balanceProtocol);
  }
  function setMarginScale(int256 _marginScale) external onlyGuardian {
    marginScale = _marginScale;
  }
  function setLiquidityPerc(uint256 _liquidityPerc) external onlyGuardian {
    require(_liquidityPerc <= 100);
    liquidityPerc = _liquidityPerc;
  }
  receive() external payable {
    require(msg.sender == Swap.WETH, "Not WETH");
  }
}