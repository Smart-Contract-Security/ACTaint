pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./DerbyToken.sol";
import "./Interfaces/IVault.sol";
import "./Interfaces/IController.sol";
import "./Interfaces/IXProvider.sol";
contract Game is ERC721, ReentrancyGuard {
  using SafeERC20 for IERC20;
  struct Basket {
    uint256 vaultNumber;
    uint256 lastRebalancingPeriod;
    int256 nrOfAllocatedTokens;
    int256 totalUnRedeemedRewards;
    int256 totalRedeemedRewards;
    mapping(uint256 => mapping(uint256 => int256)) allocations;
  }
  struct vaultInfo {
    uint256 rebalancingPeriod;
    mapping(uint32 => address) vaultAddress;
    mapping(uint256 => int256) deltaAllocationChain;
    mapping(uint256 => mapping(uint256 => int256)) deltaAllocationProtocol;
    mapping(uint32 => mapping(uint256 => mapping(uint256 => int256))) rewardPerLockedToken;
  }
  address private dao;
  address private guardian;
  address public xProvider;
  address public homeVault;
  IController public controller;
  IERC20 public derbyToken;
  uint256 private latestBasketId;
  uint32[] public chainIds;
  uint256 public rebalanceInterval; 
  uint256 public lastTimeStamp;
  int256 internal negativeRewardThreshold;
  uint256 internal negativeRewardFactor;
  mapping(uint256 => Basket) private baskets;
  mapping(uint256 => uint256) public latestProtocolId;
  mapping(uint256 => vaultInfo) internal vaults;
  mapping(uint256 => mapping(uint32 => bool)) public isXChainRebalancing;
  event PushProtocolAllocations(uint32 chain, address vault, int256[] deltas);
  event PushedAllocationsToController(uint256 vaultNumber, int256[] deltas);
  event BasketId(address owner, uint256 basketId);
  modifier onlyDao() {
    require(msg.sender == dao, "Game: only DAO");
    _;
  }
  modifier onlyBasketOwner(uint256 _basketId) {
    require(msg.sender == ownerOf(_basketId), "Game: Not the owner of the basket");
    _;
  }
  modifier onlyXProvider() {
    require(msg.sender == xProvider, "Game: only xProvider");
    _;
  }
  modifier onlyGuardian() {
    require(msg.sender == guardian, "Game: only Guardian");
    _;
  }
  constructor(
    string memory name_,
    string memory symbol_,
    address _derbyToken,
    address _dao,
    address _guardian,
    address _controller
  ) ERC721(name_, symbol_) {
    derbyToken = IERC20(_derbyToken);
    controller = IController(_controller);
    dao = _dao;
    guardian = _guardian;
    lastTimeStamp = block.timestamp;
  }
  function addDeltaAllocationChain(
    uint256 _vaultNumber,
    uint256 _chainId,
    int256 _deltaAllocation
  ) internal {
    vaults[_vaultNumber].deltaAllocationChain[_chainId] += _deltaAllocation;
  }
  function getDeltaAllocationChain(
    uint256 _vaultNumber,
    uint256 _chainId
  ) public view returns (int256) {
    return vaults[_vaultNumber].deltaAllocationChain[_chainId];
  }
  function addDeltaAllocationProtocol(
    uint256 _vaultNumber,
    uint256 _chainId,
    uint256 _protocolNum,
    int256 _deltaAllocation
  ) internal {
    vaults[_vaultNumber].deltaAllocationProtocol[_chainId][_protocolNum] += _deltaAllocation;
  }
  function getDeltaAllocationProtocol(
    uint256 _vaultNumber,
    uint256 _chainId,
    uint256 _protocolNum
  ) public view returns (int256) {
    return vaults[_vaultNumber].deltaAllocationProtocol[_chainId][_protocolNum];
  }
  function setBasketTotalAllocatedTokens(
    uint256 _basketId,
    int256 _allocation
  ) internal onlyBasketOwner(_basketId) {
    baskets[_basketId].nrOfAllocatedTokens += _allocation;
    require(basketTotalAllocatedTokens(_basketId) >= 0, "Basket: underflow");
  }
  function basketTotalAllocatedTokens(uint256 _basketId) public view returns (int256) {
    return baskets[_basketId].nrOfAllocatedTokens;
  }
  function setBasketAllocationInProtocol(
    uint256 _basketId,
    uint256 _chainId,
    uint256 _protocolId,
    int256 _allocation
  ) internal onlyBasketOwner(_basketId) {
    baskets[_basketId].allocations[_chainId][_protocolId] += _allocation;
    require(basketAllocationInProtocol(_basketId, _chainId, _protocolId) >= 0, "Basket: underflow");
  }
  function basketAllocationInProtocol(
    uint256 _basketId,
    uint256 _chainId,
    uint256 _protocolId
  ) public view onlyBasketOwner(_basketId) returns (int256) {
    return baskets[_basketId].allocations[_chainId][_protocolId];
  }
  function setBasketRebalancingPeriod(
    uint256 _basketId,
    uint256 _vaultNumber
  ) internal onlyBasketOwner(_basketId) {
    baskets[_basketId].lastRebalancingPeriod = vaults[_vaultNumber].rebalancingPeriod + 1;
  }
  function basketUnredeemedRewards(
    uint256 _basketId
  ) external view onlyBasketOwner(_basketId) returns (int256) {
    return baskets[_basketId].totalUnRedeemedRewards;
  }
  function basketRedeemedRewards(
    uint256 _basketId
  ) external view onlyBasketOwner(_basketId) returns (int) {
    return baskets[_basketId].totalRedeemedRewards;
  }
  function mintNewBasket(uint256 _vaultNumber) external returns (uint256) {
    baskets[latestBasketId].vaultNumber = _vaultNumber;
    baskets[latestBasketId].lastRebalancingPeriod = vaults[_vaultNumber].rebalancingPeriod + 1;
    _safeMint(msg.sender, latestBasketId);
    latestBasketId++;
    emit BasketId(msg.sender, latestBasketId - 1);
    return latestBasketId - 1;
  }
  function lockTokensToBasket(uint256 _lockedTokenAmount) internal {
    uint256 balanceBefore = derbyToken.balanceOf(address(this));
    derbyToken.safeTransferFrom(msg.sender, address(this), _lockedTokenAmount);
    uint256 balanceAfter = derbyToken.balanceOf(address(this));
    require((balanceAfter - balanceBefore - _lockedTokenAmount) == 0, "Error lock: under/overflow");
  }
  function unlockTokensFromBasket(uint256 _basketId, uint256 _unlockedTokenAmount) internal {
    uint256 tokensBurned = redeemNegativeRewards(_basketId, _unlockedTokenAmount);
    uint256 tokensToUnlock = _unlockedTokenAmount -= tokensBurned;
    uint256 balanceBefore = derbyToken.balanceOf(address(this));
    derbyToken.safeTransfer(msg.sender, tokensToUnlock);
    uint256 balanceAfter = derbyToken.balanceOf(address(this));
    require((balanceBefore - balanceAfter - tokensToUnlock) == 0, "Error unlock: under/overflow");
  }
  function redeemNegativeRewards(
    uint256 _basketId,
    uint256 _unlockedTokens
  ) internal returns (uint256) {
    int256 unredeemedRewards = baskets[_basketId].totalUnRedeemedRewards;
    if (unredeemedRewards > negativeRewardThreshold) return 0;
    uint256 tokensToBurn = (uint(-unredeemedRewards) * negativeRewardFactor) / 100;
    tokensToBurn = tokensToBurn < _unlockedTokens ? tokensToBurn : _unlockedTokens;
    baskets[_basketId].totalUnRedeemedRewards += int((tokensToBurn * 100) / negativeRewardFactor);
    IERC20(derbyToken).safeTransfer(homeVault, tokensToBurn);
    return tokensToBurn;
  }
  function rebalanceBasket(
    uint256 _basketId,
    int256[][] memory _deltaAllocations
  ) external onlyBasketOwner(_basketId) nonReentrant {
    uint256 vaultNumber = baskets[_basketId].vaultNumber;
    for (uint k = 0; k < chainIds.length; k++) {
      require(!isXChainRebalancing[vaultNumber][chainIds[k]], "Game: vault is xChainRebalancing");
    }
    addToTotalRewards(_basketId);
    int256 totalDelta = settleDeltaAllocations(_basketId, vaultNumber, _deltaAllocations);
    lockOrUnlockTokens(_basketId, totalDelta);
    setBasketTotalAllocatedTokens(_basketId, totalDelta);
    setBasketRebalancingPeriod(_basketId, vaultNumber);
  }
  function settleDeltaAllocations(
    uint256 _basketId,
    uint256 _vaultNumber,
    int256[][] memory _deltaAllocations
  ) internal returns (int256 totalDelta) {
    for (uint256 i = 0; i < _deltaAllocations.length; i++) {
      int256 chainTotal;
      uint32 chain = chainIds[i];
      uint256 latestProtocol = latestProtocolId[chain];
      require(_deltaAllocations[i].length == latestProtocol, "Invalid allocation length");
      for (uint256 j = 0; j < latestProtocol; j++) {
        int256 allocation = _deltaAllocations[i][j];
        if (allocation == 0) continue;
        chainTotal += allocation;
        addDeltaAllocationProtocol(_vaultNumber, chain, j, allocation);
        setBasketAllocationInProtocol(_basketId, chain, j, allocation);
      }
      totalDelta += chainTotal;
      addDeltaAllocationChain(_vaultNumber, chain, chainTotal);
    }
  }
  function addToTotalRewards(uint256 _basketId) internal onlyBasketOwner(_basketId) {
    if (baskets[_basketId].nrOfAllocatedTokens == 0) return;
    uint256 vaultNum = baskets[_basketId].vaultNumber;
    uint256 currentRebalancingPeriod = vaults[vaultNum].rebalancingPeriod;
    uint256 lastRebalancingPeriod = baskets[_basketId].lastRebalancingPeriod;
    if (currentRebalancingPeriod <= lastRebalancingPeriod) return;
    for (uint k = 0; k < chainIds.length; k++) {
      uint32 chain = chainIds[k];
      uint256 latestProtocol = latestProtocolId[chain];
      for (uint i = 0; i < latestProtocol; i++) {
        int256 allocation = basketAllocationInProtocol(_basketId, chain, i) / 1E18;
        if (allocation == 0) continue;
        int256 lastRebalanceReward = getRewardsPerLockedToken(
          vaultNum,
          chain,
          lastRebalancingPeriod,
          i
        );
        int256 currentReward = getRewardsPerLockedToken(
          vaultNum,
          chain,
          currentRebalancingPeriod,
          i
        );
        baskets[_basketId].totalUnRedeemedRewards +=
          (currentReward - lastRebalanceReward) *
          allocation;
      }
    }
  }
  function lockOrUnlockTokens(uint256 _basketId, int256 _totalDelta) internal {
    if (_totalDelta > 0) {
      lockTokensToBasket(uint256(_totalDelta));
    }
    if (_totalDelta < 0) {
      int256 oldTotal = basketTotalAllocatedTokens(_basketId);
      int256 newTotal = oldTotal + _totalDelta;
      int256 tokensToUnlock = oldTotal - newTotal;
      require(oldTotal >= tokensToUnlock, "Not enough tokens locked");
      unlockTokensFromBasket(_basketId, uint256(tokensToUnlock));
    }
  }
  function pushAllocationsToController(uint256 _vaultNumber) external payable {
    require(rebalanceNeeded(), "No rebalance needed");
    for (uint k = 0; k < chainIds.length; k++) {
      require(
        getVaultAddress(_vaultNumber, chainIds[k]) != address(0),
        "Game: not a valid vaultnumber"
      );
      require(
        !isXChainRebalancing[_vaultNumber][chainIds[k]],
        "Game: vault is already rebalancing"
      );
      isXChainRebalancing[_vaultNumber][chainIds[k]] = true;
    }
    int256[] memory deltas = allocationsToArray(_vaultNumber);
    IXProvider(xProvider).pushAllocations{value: msg.value}(_vaultNumber, deltas);
    lastTimeStamp = block.timestamp;
    vaults[_vaultNumber].rebalancingPeriod++;
    emit PushedAllocationsToController(_vaultNumber, deltas);
  }
  function allocationsToArray(uint256 _vaultNumber) internal returns (int256[] memory deltas) {
    deltas = new int[](chainIds.length);
    for (uint256 i = 0; i < chainIds.length; i++) {
      uint32 chain = chainIds[i];
      deltas[i] = getDeltaAllocationChain(_vaultNumber, chain);
      vaults[_vaultNumber].deltaAllocationChain[chain] = 0;
    }
  }
  function pushAllocationsToVaults(uint256 _vaultNumber, uint32 _chain) external payable {
    address vault = getVaultAddress(_vaultNumber, _chain);
    require(vault != address(0), "Game: not a valid vaultnumber");
    require(isXChainRebalancing[_vaultNumber][_chain], "Vault is not rebalancing");
    int256[] memory deltas = protocolAllocationsToArray(_vaultNumber, _chain);
    IXProvider(xProvider).pushProtocolAllocationsToVault{value: msg.value}(_chain, vault, deltas);
    emit PushProtocolAllocations(_chain, getVaultAddress(_vaultNumber, _chain), deltas);
    isXChainRebalancing[_vaultNumber][_chain] = false;
  }
  function protocolAllocationsToArray(
    uint256 _vaultNumber,
    uint32 _chainId
  ) internal returns (int256[] memory deltas) {
    uint256 latestId = latestProtocolId[_chainId];
    deltas = new int[](latestId);
    for (uint256 i = 0; i < latestId; i++) {
      deltas[i] = getDeltaAllocationProtocol(_vaultNumber, _chainId, i);
      vaults[_vaultNumber].deltaAllocationProtocol[_chainId][i] = 0;
    }
  }
  function settleRewards(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256[] memory _rewards
  ) external onlyXProvider {
    settleRewardsInt(_vaultNumber, _chainId, _rewards);
  }
  function settleRewardsInt(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256[] memory _rewards
  ) internal {
    uint256 rebalancingPeriod = vaults[_vaultNumber].rebalancingPeriod;
    for (uint256 i = 0; i < _rewards.length; i++) {
      int256 lastReward = getRewardsPerLockedToken(
        _vaultNumber,
        _chainId,
        rebalancingPeriod - 1,
        i
      );
      vaults[_vaultNumber].rewardPerLockedToken[_chainId][rebalancingPeriod][i] =
        lastReward +
        _rewards[i];
    }
  }
  function getRewardsPerLockedToken(
    uint256 _vaultNumber,
    uint32 _chainId,
    uint256 _rebalancingPeriod,
    uint256 _protocolId
  ) internal view returns (int256) {
    return vaults[_vaultNumber].rewardPerLockedToken[_chainId][_rebalancingPeriod][_protocolId];
  }
  function redeemRewards(uint256 _basketId) external onlyBasketOwner(_basketId) {
    int256 amount = baskets[_basketId].totalUnRedeemedRewards;
    require(amount > 0, "Nothing to claim");
    baskets[_basketId].totalRedeemedRewards += amount;
    baskets[_basketId].totalUnRedeemedRewards = 0;
    IVault(homeVault).redeemRewardsGame(uint256(amount), msg.sender);
  }
  function rebalanceNeeded() public view returns (bool) {
    return (block.timestamp - lastTimeStamp) > rebalanceInterval || msg.sender == guardian;
  }
  function getVaultAddress(uint256 _vaultNumber, uint32 _chainId) internal view returns (address) {
    return vaults[_vaultNumber].vaultAddress[_chainId];
  }
  function getDao() public view returns (address) {
    return dao;
  }
  function getGuardian() public view returns (address) {
    return guardian;
  }
  function getChainIds() public view returns (uint32[] memory) {
    return chainIds;
  }
  function getRebalancingPeriod(uint256 _vaultNumber) public view returns (uint256) {
    return vaults[_vaultNumber].rebalancingPeriod;
  }
  function setXProvider(address _xProvider) external onlyDao {
    xProvider = _xProvider;
  }
  function setHomeVault(address _homeVault) external onlyDao {
    homeVault = _homeVault;
  }
  function setRebalanceInterval(uint256 _timestampInternal) external onlyDao {
    rebalanceInterval = _timestampInternal;
  }
  function setDao(address _dao) external onlyDao {
    dao = _dao;
  }
  function setGuardian(address _guardian) external onlyDao {
    guardian = _guardian;
  }
  function setDerbyToken(address _derbyToken) external onlyDao {
    derbyToken = IERC20(_derbyToken);
  }
  function setNegativeRewardThreshold(int256 _threshold) external onlyDao {
    negativeRewardThreshold = _threshold;
  }
  function setNegativeRewardFactor(uint256 _factor) external onlyDao {
    negativeRewardFactor = _factor;
  }
  function setVaultAddress(
    uint256 _vaultNumber,
    uint32 _chainId,
    address _address
  ) external onlyGuardian {
    vaults[_vaultNumber].vaultAddress[_chainId] = _address;
  }
  function setLatestProtocolId(uint32 _chainId, uint256 _latestProtocolId) external onlyGuardian {
    latestProtocolId[_chainId] = _latestProtocolId;
  }
  function setChainIds(uint32[] memory _chainIds) external onlyGuardian {
    chainIds = _chainIds;
  }
  function setRebalancingState(
    uint256 _vaultNumber,
    uint32 _chain,
    bool _state
  ) external onlyGuardian {
    isXChainRebalancing[_vaultNumber][_chain] = _state;
  }
  function setRebalancingPeriod(uint256 _vaultNumber, uint256 _period) external onlyGuardian {
    vaults[_vaultNumber].rebalancingPeriod = _period;
  }
  function settleRewardsGuard(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256[] memory _rewards
  ) external onlyGuardian {
    settleRewardsInt(_vaultNumber, _chainId, _rewards);
  }
}