pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Interfaces/IXProvider.sol";
contract XChainController {
  using SafeERC20 for IERC20;
  struct vaultInfo {
    int256 totalCurrentAllocation;
    uint256 totalUnderlying;
    uint256 totalSupply;
    uint256 totalWithdrawalRequests;
    mapping(uint32 => bool) chainIdOff;
    mapping(uint32 => int256) currentAllocationPerChain;
    mapping(uint32 => uint256) totalUnderlyingPerChain;
    mapping(uint32 => address) vaultChainAddress;
    mapping(uint32 => address) vaultUnderlyingAddress;
    mapping(uint32 => uint256) withdrawalRequests;
    mapping(uint32 => uint256) amountToDepositPerChain;
  }
  struct vaultStages {
    uint256 activeVaults;
    bool ready; 
    bool allocationsReceived; 
    uint256 underlyingReceived; 
    uint256 fundsReceived; 
    uint256 fundsSent; 
  }
  address private dao;
  address private guardian;
  address public game;
  address public xProviderAddr;
  IXProvider public xProvider;
  uint32[] public chainIds;
  uint32 public homeChain;
  int256 public minimumAmount;
  mapping(uint256 => vaultInfo) internal vaults;
  mapping(uint256 => vaultStages) public vaultStage;
  event SendXChainAmount(
    address _vault,
    uint32 _chainId,
    uint256 _amountToSendXChain,
    uint256 _exchangeRate,
    bool _receivingFunds
  );
  event SentFundsToVault(address _vault, uint32 _chainId, uint256 _amount, address _asset);
  modifier onlyGame() {
    require(msg.sender == game, "xController: only Game");
    _;
  }
  modifier onlyDao() {
    require(msg.sender == dao, "xController: only DAO");
    _;
  }
  modifier onlyGuardian() {
    require(msg.sender == guardian, "xController: only Guardian");
    _;
  }
  modifier onlyXProvider() {
    require(msg.sender == address(xProvider), "xController: only xProviderAddr");
    _;
  }
  modifier onlyWhenReady(uint256 _vaultNumber) {
    require(vaultStage[_vaultNumber].ready, "Not all vaults are ready");
    _;
  }
  modifier onlyWhenAllocationsReceived(uint256 _vaultNumber) {
    require(vaultStage[_vaultNumber].allocationsReceived, "Allocations not received from game");
    _;
  }
  modifier onlyWhenUnderlyingsReceived(uint256 _vaultNumber) {
    require(
      vaultStage[_vaultNumber].underlyingReceived == vaultStage[_vaultNumber].activeVaults,
      "Not all underlyings received"
    );
    _;
  }
  modifier onlyWhenFundsReceived(uint256 _vaultNumber) {
    require(
      vaultStage[_vaultNumber].fundsReceived == vaultStage[_vaultNumber].activeVaults,
      "Not all funds received"
    );
    _;
  }
  constructor(address _game, address _dao, address _guardian, uint32 _homeChain) {
    game = _game;
    dao = _dao;
    guardian = _guardian;
    homeChain = _homeChain;
    minimumAmount = 1000e6;
  }
  function setActiveVaults(uint256 _vaultNumber, uint256 _activeVaults) internal {
    vaultStage[_vaultNumber].activeVaults = _activeVaults;
  }
  function setReady(uint256 _vaultNumber, bool _state) internal {
    vaultStage[_vaultNumber].ready = _state;
  }
  function setAllocationsReceived(
    uint256 _vaultNumber,
    bool _state
  ) internal onlyWhenReady(_vaultNumber) {
    vaultStage[_vaultNumber].allocationsReceived = _state;
  }
  function upUnderlyingReceived(
    uint256 _vaultNumber
  ) internal onlyWhenAllocationsReceived(_vaultNumber) {
    vaultStage[_vaultNumber].underlyingReceived++;
  }
  function upFundsReceived(
    uint256 _vaultNumber
  ) external onlyXProvider onlyWhenUnderlyingsReceived(_vaultNumber) {
    vaultStage[_vaultNumber].fundsReceived++;
  }
  function resetVaultStages(uint256 _vaultNumber) internal {
    vaultStage[_vaultNumber].ready = true;
    vaultStage[_vaultNumber].allocationsReceived = false;
    vaultStage[_vaultNumber].underlyingReceived = 0;
    vaultStage[_vaultNumber].fundsReceived = 0;
    vaultStage[_vaultNumber].fundsSent = 0;
  }
  function resetVaultUnderlying(uint256 _vaultNumber) internal {
    vaults[_vaultNumber].totalUnderlying = 0;
    vaultStage[_vaultNumber].underlyingReceived = 0;
    vaults[_vaultNumber].totalSupply = 0;
  }
  function resetVaultUnderlyingForChain(uint256 _vaultNumber, uint32 _chainId) internal {
    vaults[_vaultNumber].totalUnderlyingPerChain[_chainId] = 0;
  }
  function receiveAllocationsFromGame(
    uint256 _vaultNumber,
    int256[] memory _deltas
  ) external onlyXProvider onlyWhenReady(_vaultNumber) {
    return receiveAllocationsFromGameInt(_vaultNumber, _deltas);
  }
  function receiveAllocationsFromGameInt(uint256 _vaultNumber, int256[] memory _deltas) internal {
    uint256 activeVaults;
    for (uint256 i = 0; i < chainIds.length; i++) {
      uint32 chain = chainIds[i];
      activeVaults += settleCurrentAllocation(_vaultNumber, chain, _deltas[i]);
      resetVaultUnderlyingForChain(_vaultNumber, chain);
    }
    resetVaultUnderlying(_vaultNumber);
    setActiveVaults(_vaultNumber, activeVaults);
    setAllocationsReceived(_vaultNumber, true);
    setReady(_vaultNumber, false);
  }
  function settleCurrentAllocation(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256 _deltas
  ) internal returns (uint256 activeVault) {
    if (getCurrentAllocation(_vaultNumber, _chainId) == 0 && _deltas == 0) {
      vaults[_vaultNumber].chainIdOff[_chainId] = true;
      activeVault = 0;
    } else {
      vaults[_vaultNumber].chainIdOff[_chainId] = false;
      activeVault = 1;
    }
    vaults[_vaultNumber].totalCurrentAllocation += _deltas;
    vaults[_vaultNumber].currentAllocationPerChain[_chainId] += _deltas;
    require(vaults[_vaultNumber].totalCurrentAllocation >= 0, "Allocation underflow");
  }
  function sendFeedbackToVault(uint256 _vaultNumber, uint32 _chainId) external payable {
    address vault = getVaultAddress(_vaultNumber, _chainId);
    require(vault != address(0), "xChainController: not a valid vaultnumber");
    xProvider.pushStateFeedbackToVault{value: msg.value}(
      vault,
      _chainId,
      vaults[_vaultNumber].chainIdOff[_chainId]
    );
  }
  function setTotalUnderlying(
    uint256 _vaultNumber,
    uint32 _chainId,
    uint256 _underlying,
    uint256 _totalSupply,
    uint256 _withdrawalRequests
  ) external onlyXProvider onlyWhenAllocationsReceived(_vaultNumber) {
    require(getTotalUnderlyingOnChain(_vaultNumber, _chainId) == 0, "TotalUnderlying already set");
    setTotalUnderlyingInt(_vaultNumber, _chainId, _underlying, _totalSupply, _withdrawalRequests);
  }
  function setTotalUnderlyingInt(
    uint256 _vaultNumber,
    uint32 _chainId,
    uint256 _underlying,
    uint256 _totalSupply,
    uint256 _withdrawalRequests
  ) internal {
    vaults[_vaultNumber].totalUnderlyingPerChain[_chainId] = _underlying;
    vaults[_vaultNumber].withdrawalRequests[_chainId] = _withdrawalRequests;
    vaults[_vaultNumber].totalSupply += _totalSupply;
    vaults[_vaultNumber].totalUnderlying += _underlying;
    vaults[_vaultNumber].totalWithdrawalRequests += _withdrawalRequests;
    vaultStage[_vaultNumber].underlyingReceived++;
  }
  function pushVaultAmounts(
    uint256 _vaultNumber,
    uint16 _chain
  ) external payable onlyWhenUnderlyingsReceived(_vaultNumber) {
    address vault = getVaultAddress(_vaultNumber, _chain);
    require(vault != address(0), "xChainController: not a valid vaultnumber");
    int256 totalAllocation = getCurrentTotalAllocation(_vaultNumber);
    uint256 totalWithdrawalRequests = getTotalWithdrawalRequests(_vaultNumber);
    uint256 totalUnderlying = getTotalUnderlyingVault(_vaultNumber) - totalWithdrawalRequests;
    uint256 totalSupply = getTotalSupply(_vaultNumber);
    uint256 decimals = xProvider.getDecimals(vault);
    uint256 newExchangeRate = (totalUnderlying * (10 ** decimals)) / totalSupply;
    if (!getVaultChainIdOff(_vaultNumber, _chain)) {
      int256 amountToChain = calcAmountToChain(
        _vaultNumber,
        _chain,
        totalUnderlying,
        totalAllocation
      );
      (int256 amountToDeposit, uint256 amountToWithdraw) = calcDepositWithdraw(
        _vaultNumber,
        _chain,
        amountToChain
      );
      sendXChainAmount(_vaultNumber, _chain, amountToDeposit, amountToWithdraw, newExchangeRate);
    }
  }
  function calcDepositWithdraw(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256 _amountToChain
  ) internal view returns (int256, uint256) {
    uint256 currentUnderlying = getTotalUnderlyingOnChain(_vaultNumber, _chainId);
    int256 amountToDeposit = _amountToChain - int256(currentUnderlying);
    uint256 amountToWithdraw = amountToDeposit < 0
      ? currentUnderlying - uint256(_amountToChain)
      : 0;
    return (amountToDeposit, amountToWithdraw);
  }
  function calcAmountToChain(
    uint256 _vaultNumber,
    uint32 _chainId,
    uint256 _totalUnderlying,
    int256 _totalAllocation
  ) internal view returns (int256) {
    int256 allocation = getCurrentAllocation(_vaultNumber, _chainId);
    uint256 withdrawalRequests = getWithdrawalRequests(_vaultNumber, _chainId);
    int256 amountToChain = (int(_totalUnderlying) * allocation) / _totalAllocation;
    amountToChain += int(withdrawalRequests);
    return amountToChain;
  }
  function sendXChainAmount(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256 _amountDeposit,
    uint256 _amountToWithdraw,
    uint256 _exchangeRate
  ) internal {
    address vault = getVaultAddress(_vaultNumber, _chainId);
    bool receivingFunds;
    uint256 amountToSend = 0;
    if (_amountDeposit > 0 && _amountDeposit < minimumAmount) {
      vaultStage[_vaultNumber].fundsReceived++;
    } else if (_amountDeposit >= minimumAmount) {
      receivingFunds = true;
      setAmountToDeposit(_vaultNumber, _chainId, _amountDeposit);
      vaultStage[_vaultNumber].fundsReceived++;
    }
    if (_amountToWithdraw > 0 && _amountToWithdraw < uint(minimumAmount)) {
      vaultStage[_vaultNumber].fundsReceived++;
    } else if (_amountToWithdraw >= uint(minimumAmount)) {
      amountToSend = _amountToWithdraw;
    }
    xProvider.pushSetXChainAllocation{value: msg.value}(
      vault,
      _chainId,
      amountToSend,
      _exchangeRate,
      receivingFunds
    );
    emit SendXChainAmount(vault, _chainId, amountToSend, _exchangeRate, receivingFunds);
  }
  function sendFundsToVault(
    uint256 _vaultNumber,
    uint256 _slippage,
    uint32 _chain,
    uint256 _relayerFee
  ) external payable onlyWhenFundsReceived(_vaultNumber) {
    address vault = getVaultAddress(_vaultNumber, _chain);
    require(vault != address(0), "xChainController: not a valid vaultnumber");
    if (!getVaultChainIdOff(_vaultNumber, _chain)) {
      uint256 amountToDeposit = getAmountToDeposit(_vaultNumber, _chain);
      if (amountToDeposit > 0) {
        address underlying = getUnderlyingAddress(_vaultNumber, _chain);
        uint256 balance = IERC20(underlying).balanceOf(address(this));
        if (amountToDeposit > balance) amountToDeposit = balance;
        IERC20(underlying).safeIncreaseAllowance(address(xProvider), amountToDeposit);
        xProvider.xTransferToVaults{value: msg.value}(
          vault,
          _chain,
          amountToDeposit,
          underlying,
          _slippage,
          _relayerFee
        );
        setAmountToDeposit(_vaultNumber, _chain, 0);
        emit SentFundsToVault(vault, _chain, amountToDeposit, underlying);
      }
    }
    vaultStage[_vaultNumber].fundsSent++;
    if (vaultStage[_vaultNumber].fundsSent == chainIds.length) resetVaultStages(_vaultNumber);
  }
  function getTotalUnderlyingOnChain(
    uint256 _vaultNumber,
    uint32 _chainId
  ) internal view returns (uint256) {
    return vaults[_vaultNumber].totalUnderlyingPerChain[_chainId];
  }
  function getTotalUnderlyingVault(
    uint256 _vaultNumber
  ) internal view onlyWhenUnderlyingsReceived(_vaultNumber) returns (uint256) {
    return vaults[_vaultNumber].totalUnderlying;
  }
  function getVaultAddress(uint256 _vaultNumber, uint32 _chainId) internal view returns (address) {
    return vaults[_vaultNumber].vaultChainAddress[_chainId];
  }
  function getUnderlyingAddress(
    uint256 _vaultNumber,
    uint32 _chainId
  ) internal view returns (address) {
    return vaults[_vaultNumber].vaultUnderlyingAddress[_chainId];
  }
  function getCurrentAllocation(
    uint256 _vaultNumber,
    uint32 _chainId
  ) internal view returns (int256) {
    return vaults[_vaultNumber].currentAllocationPerChain[_chainId];
  }
  function getCurrentTotalAllocation(uint256 _vaultNumber) internal view returns (int256) {
    return vaults[_vaultNumber].totalCurrentAllocation;
  }
  function getVaultChainIdOff(uint256 _vaultNumber, uint32 _chainId) public view returns (bool) {
    return vaults[_vaultNumber].chainIdOff[_chainId];
  }
  function setAmountToDeposit(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256 _amountToDeposit
  ) internal {
    vaults[_vaultNumber].amountToDepositPerChain[_chainId] = uint256(_amountToDeposit);
  }
  function getAmountToDeposit(
    uint256 _vaultNumber,
    uint32 _chainId
  ) internal view returns (uint256) {
    return vaults[_vaultNumber].amountToDepositPerChain[_chainId];
  }
  function getTotalSupply(uint256 _vaultNumber) internal view returns (uint256) {
    return vaults[_vaultNumber].totalSupply;
  }
  function getWithdrawalRequests(
    uint256 _vaultNumber,
    uint32 _chainId
  ) internal view returns (uint256) {
    return vaults[_vaultNumber].withdrawalRequests[_chainId];
  }
  function getTotalWithdrawalRequests(uint256 _vaultNumber) internal view returns (uint256) {
    return vaults[_vaultNumber].totalWithdrawalRequests;
  }
  function getChainIds() public view returns (uint32[] memory) {
    return chainIds;
  }
  function getDao() public view returns (address) {
    return dao;
  }
  function getGuardian() public view returns (address) {
    return guardian;
  }
  function setVaultChainAddress(
    uint256 _vaultNumber,
    uint32 _chainId,
    address _address,
    address _underlying
  ) external onlyDao {
    vaults[_vaultNumber].vaultChainAddress[_chainId] = _address;
    vaults[_vaultNumber].vaultUnderlyingAddress[_chainId] = _underlying;
  }
  function setHomeXProvider(address _xProvider) external onlyDao {
    xProvider = IXProvider(_xProvider);
  }
  function setHomeChainId(uint32 _homeChainId) external onlyDao {
    homeChain = _homeChainId;
  }
  function setDao(address _dao) external onlyDao {
    dao = _dao;
  }
  function setGuardian(address _guardian) external onlyDao {
    guardian = _guardian;
  }
  function setGame(address _game) external onlyDao {
    game = _game;
  }
  function setMinimumAmount(int256 _amount) external onlyDao {
    minimumAmount = _amount;
  }
  function setChainIds(uint32[] memory _chainIds) external onlyGuardian {
    chainIds = _chainIds;
  }
  function resetVaultStagesDao(uint256 _vaultNumber) external onlyGuardian {
    return resetVaultStages(_vaultNumber);
  }
  function receiveAllocationsFromGameGuard(
    uint256 _vaultNumber,
    int256[] memory _deltas
  ) external onlyGuardian {
    return receiveAllocationsFromGameInt(_vaultNumber, _deltas);
  }
  function setTotalUnderlyingGuard(
    uint256 _vaultNumber,
    uint32 _chainId,
    uint256 _underlying,
    uint256 _totalSupply,
    uint256 _withdrawalRequests
  ) external onlyGuardian {
    return
      setTotalUnderlyingInt(_vaultNumber, _chainId, _underlying, _totalSupply, _withdrawalRequests);
  }
  function setFundsReceivedGuard(
    uint256 _vaultNumber,
    uint256 _fundsReceived
  ) external onlyGuardian {
    vaultStage[_vaultNumber].fundsReceived = _fundsReceived;
  }
  function setActiveVaultsGuard(uint256 _vaultNumber, uint256 _activeVaults) external onlyGuardian {
    vaultStage[_vaultNumber].activeVaults = _activeVaults;
  }
  function setReadyGuard(uint256 _vaultNumber, bool _state) external onlyGuardian {
    vaultStage[_vaultNumber].ready = _state;
  }
  function setAllocationsReceivedGuard(uint256 _vaultNumber, bool _state) external onlyGuardian {
    vaultStage[_vaultNumber].allocationsReceived = _state;
  }
  function setUnderlyingReceivedGuard(
    uint256 _vaultNumber,
    uint256 _underlyingReceived
  ) external onlyGuardian {
    vaultStage[_vaultNumber].underlyingReceived = _underlyingReceived;
  }
}