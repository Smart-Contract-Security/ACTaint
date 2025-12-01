pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Interfaces/IVault.sol";
import "./Interfaces/IXChainController.sol";
import "./Interfaces/IGame.sol";
import "./Interfaces/ExternalInterfaces/IConnext.sol";
import "./Interfaces/ExternalInterfaces/IXReceiver.sol";
contract XProvider is IXReceiver {
  using SafeERC20 for IERC20;
  address public immutable connext;
  address private dao;
  address private guardian;
  address public xController;
  address public xControllerProvider;
  address public game;
  uint32 public homeChain;
  uint32 public xControllerChain;
  uint32 public gameChain;
  mapping(uint32 => address) public trustedRemoteConnext;
  mapping(address => bool) public vaultWhitelist;
  mapping(uint256 => address) public vaults;
  event SetTrustedRemote(uint32 _srcChainId, bytes _srcAddress);
  event SetTrustedRemoteConnext(uint32 _srcChainId, address _srcAddress);
  modifier onlyDao() {
    require(msg.sender == dao, "xProvider: only DAO");
    _;
  }
  modifier onlyGuardian() {
    require(msg.sender == guardian, "only Guardian");
    _;
  }
  modifier onlyController() {
    require(msg.sender == xController, "xProvider: only Controller");
    _;
  }
  modifier onlyVaults() {
    require(vaultWhitelist[msg.sender], "xProvider: only vault");
    _;
  }
  modifier onlyGame() {
    require(msg.sender == game, "xProvider: only Game");
    _;
  }
  modifier onlySelf() {
    require(msg.sender == address(this), "xProvider: only Self");
    _;
  }
  modifier onlySelfOrVault() {
    require(
      msg.sender == address(this) || vaultWhitelist[msg.sender],
      "xProvider: only Self or Vault"
    );
    _;
  }
  modifier onlySource(address _originSender, uint32 _origin) {
    require(_originSender == trustedRemoteConnext[_origin] && msg.sender == connext, "Not trusted");
    _;
  }
  constructor(
    address _connext,
    address _dao,
    address _guardian,
    address _game,
    address _xController,
    uint32 _homeChain
  ) {
    connext = _connext;
    dao = _dao;
    guardian = _guardian;
    game = _game;
    xController = _xController;
    homeChain = _homeChain;
  }
  function xSend(uint32 _destinationDomain, bytes memory _callData, uint256 _relayerFee) internal {
    address target = trustedRemoteConnext[_destinationDomain];
    require(target != address(0), "XProvider: destination chain not trusted");
    uint256 relayerFee = _relayerFee != 0 ? _relayerFee : msg.value;
    IConnext(connext).xcall{value: relayerFee}(
      _destinationDomain, 
      target, 
      address(0), 
      msg.sender, 
      0, 
      0, 
      _callData 
    );
  }
  function xTransfer(
    address _token,
    uint256 _amount,
    address _recipient,
    uint32 _destinationDomain,
    uint256 _slippage,
    uint256 _relayerFee
  ) internal {
    require(
      IERC20(_token).allowance(msg.sender, address(this)) >= _amount,
      "User must approve amount"
    );
    IERC20(_token).transferFrom(msg.sender, address(this), _amount);
    IERC20(_token).approve(address(connext), _amount);
    IConnext(connext).xcall{value: (msg.value - _relayerFee)}(
      _destinationDomain, 
      _recipient, 
      _token, 
      msg.sender, 
      _amount, 
      _slippage, 
      bytes("") 
    );
  }
  function xReceive(
    bytes32 _transferId,
    uint256 _amount,
    address _asset,
    address _originSender,
    uint32 _origin,
    bytes memory _callData
  ) external onlySource(_originSender, _origin) returns (bytes memory) {
    (bool success, ) = address(this).call(_callData);
    require(success, "xReceive: No success");
  }
  function pushAllocations(
    uint256 _vaultNumber,
    int256[] memory _deltas
  ) external payable onlyGame {
    if (homeChain == xControllerChain) {
      return IXChainController(xController).receiveAllocationsFromGame(_vaultNumber, _deltas);
    }
    bytes4 selector = bytes4(keccak256("receiveAllocations(uint256,int256[])"));
    bytes memory callData = abi.encodeWithSelector(selector, _vaultNumber, _deltas);
    xSend(xControllerChain, callData, 0);
  }
  function receiveAllocations(uint256 _vaultNumber, int256[] memory _deltas) external onlySelf {
    return IXChainController(xController).receiveAllocationsFromGame(_vaultNumber, _deltas);
  }
  function pushTotalUnderlying(
    uint256 _vaultNumber,
    uint32 _chainId,
    uint256 _underlying,
    uint256 _totalSupply,
    uint256 _withdrawalRequests
  ) external payable onlyVaults {
    if (_chainId == xControllerChain) {
      return
        IXChainController(xController).setTotalUnderlying(
          _vaultNumber,
          _chainId,
          _underlying,
          _totalSupply,
          _withdrawalRequests
        );
    } else {
      bytes4 selector = bytes4(
        keccak256("receiveTotalUnderlying(uint256,uint32,uint256,uint256,uint256)")
      );
      bytes memory callData = abi.encodeWithSelector(
        selector,
        _vaultNumber,
        _chainId,
        _underlying,
        _totalSupply,
        _withdrawalRequests
      );
      xSend(xControllerChain, callData, 0);
    }
  }
  function receiveTotalUnderlying(
    uint256 _vaultNumber,
    uint32 _chainId,
    uint256 _underlying,
    uint256 _totalSupply,
    uint256 _withdrawalRequests
  ) external onlySelf {
    return
      IXChainController(xController).setTotalUnderlying(
        _vaultNumber,
        _chainId,
        _underlying,
        _totalSupply,
        _withdrawalRequests
      );
  }
  function pushSetXChainAllocation(
    address _vault,
    uint32 _chainId,
    uint256 _amountToSendBack,
    uint256 _exchangeRate,
    bool _receivingFunds
  ) external payable onlyController {
    if (_chainId == homeChain) {
      return IVault(_vault).setXChainAllocation(_amountToSendBack, _exchangeRate, _receivingFunds);
    } else {
      bytes4 selector = bytes4(
        keccak256("receiveSetXChainAllocation(address,uint256,uint256,bool)")
      );
      bytes memory callData = abi.encodeWithSelector(
        selector,
        _vault,
        _amountToSendBack,
        _exchangeRate,
        _receivingFunds
      );
      xSend(_chainId, callData, 0);
    }
  }
  function receiveSetXChainAllocation(
    address _vault,
    uint256 _amountToSendBack,
    uint256 _exchangeRate,
    bool _receivingFunds
  ) external onlySelf {
    return IVault(_vault).setXChainAllocation(_amountToSendBack, _exchangeRate, _receivingFunds);
  }
  function xTransferToController(
    uint256 _vaultNumber,
    uint256 _amount,
    address _asset,
    uint256 _slippage,
    uint256 _relayerFee
  ) external payable onlyVaults {
    if (homeChain == xControllerChain) {
      IERC20(_asset).transferFrom(msg.sender, xController, _amount);
      IXChainController(xController).upFundsReceived(_vaultNumber);
    } else {
      xTransfer(_asset, _amount, xController, xControllerChain, _slippage, _relayerFee);
      pushFeedbackToXController(_vaultNumber, _relayerFee);
    }
  }
  function pushFeedbackToXController(uint256 _vaultNumber, uint256 _relayerFee) internal {
    bytes4 selector = bytes4(keccak256("receiveFeedbackToXController(uint256)"));
    bytes memory callData = abi.encodeWithSelector(selector, _vaultNumber);
    xSend(xControllerChain, callData, _relayerFee);
  }
  function receiveFeedbackToXController(uint256 _vaultNumber) external onlySelf {
    return IXChainController(xController).upFundsReceived(_vaultNumber);
  }
  function xTransferToVaults(
    address _vault,
    uint32 _chainId,
    uint256 _amount,
    address _asset,
    uint256 _slippage,
    uint256 _relayerFee
  ) external payable onlyController {
    if (_chainId == homeChain) {
      IVault(_vault).receiveFunds();
      IERC20(_asset).transferFrom(msg.sender, _vault, _amount);
    } else {
      pushFeedbackToVault(_chainId, _vault, _relayerFee);
      xTransfer(_asset, _amount, _vault, _chainId, _slippage, _relayerFee);
    }
  }
  function pushFeedbackToVault(uint32 _chainId, address _vault, uint256 _relayerFee) internal {
    bytes4 selector = bytes4(keccak256("receiveFeedbackToVault(address)"));
    bytes memory callData = abi.encodeWithSelector(selector, _vault);
    xSend(_chainId, callData, _relayerFee);
  }
  function receiveFeedbackToVault(address _vault) external onlySelfOrVault {
    return IVault(_vault).receiveFunds();
  }
  function pushProtocolAllocationsToVault(
    uint32 _chainId,
    address _vault,
    int256[] memory _deltas
  ) external payable onlyGame {
    if (_chainId == homeChain) return IVault(_vault).receiveProtocolAllocations(_deltas);
    else {
      bytes4 selector = bytes4(keccak256("receiveProtocolAllocationsToVault(address,int256[])"));
      bytes memory callData = abi.encodeWithSelector(selector, _vault, _deltas);
      xSend(_chainId, callData, 0);
    }
  }
  function receiveProtocolAllocationsToVault(
    address _vault,
    int256[] memory _deltas
  ) external onlySelf {
    return IVault(_vault).receiveProtocolAllocations(_deltas);
  }
  function pushRewardsToGame(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256[] memory _rewards
  ) external payable onlyVaults {
    if (_chainId == gameChain) {
      return IGame(game).settleRewards(_vaultNumber, _chainId, _rewards);
    } else {
      bytes4 selector = bytes4(keccak256("receiveRewardsToGame(uint256,uint32,int256[])"));
      bytes memory callData = abi.encodeWithSelector(selector, _vaultNumber, _chainId, _rewards);
      xSend(gameChain, callData, 0);
    }
  }
  function receiveRewardsToGame(
    uint256 _vaultNumber,
    uint32 _chainId,
    int256[] memory _rewards
  ) external onlySelf {
    return IGame(game).settleRewards(_vaultNumber, _chainId, _rewards);
  }
  function pushStateFeedbackToVault(
    address _vault,
    uint32 _chainId,
    bool _state
  ) external payable onlyController {
    if (_chainId == homeChain) {
      return IVault(_vault).toggleVaultOnOff(_state);
    } else {
      bytes4 selector = bytes4(keccak256("receiveStateFeedbackToVault(address,bool)"));
      bytes memory callData = abi.encodeWithSelector(selector, _vault, _state);
      xSend(_chainId, callData, 0);
    }
  }
  function receiveStateFeedbackToVault(address _vault, bool _state) external onlySelf {
    return IVault(_vault).toggleVaultOnOff(_state);
  }
  function getDecimals(address _vault) external view returns (uint256) {
    return IVault(_vault).decimals();
  }
  function getDao() public view returns (address) {
    return dao;
  }
  function setTrustedRemoteConnext(uint32 _srcChainId, address _srcAddress) external onlyDao {
    trustedRemoteConnext[_srcChainId] = _srcAddress;
    emit SetTrustedRemoteConnext(_srcChainId, _srcAddress);
  }
  function setXController(address _xController) external onlyDao {
    xController = _xController;
  }
  function setXControllerProvider(address _xControllerProvider) external onlyDao {
    xControllerProvider = _xControllerProvider;
  }
  function setXControllerChainId(uint32 _xControllerChain) external onlyDao {
    xControllerChain = _xControllerChain;
  }
  function setHomeChain(uint32 _homeChain) external onlyDao {
    homeChain = _homeChain;
  }
  function setGameChainId(uint32 _gameChain) external onlyDao {
    gameChain = _gameChain;
  }
  function toggleVaultWhitelist(address _vault) external onlyDao {
    vaultWhitelist[_vault] = !vaultWhitelist[_vault];
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
  function setVaultAddress(uint256 _vaultNumber, address _vault) external onlyDao {
    vaults[_vaultNumber] = _vault;
  }
  function sendFundsToXController(address _token) external onlyGuardian {
    require(xControllerChain == homeChain, "No xController on this chain");
    require(xController != address(0), "Zero address");
    uint256 balance = IERC20(_token).balanceOf(address(this));
    IERC20(_token).transfer(xController, balance);
  }
  function sendFundsToVault(uint256 _vaultNumber, address _token) external onlyGuardian {
    address vault = vaults[_vaultNumber];
    require(vault != address(0), "Zero address");
    uint256 balance = IERC20(_token).balanceOf(address(this));
    IERC20(_token).transfer(vault, balance);
  }
}