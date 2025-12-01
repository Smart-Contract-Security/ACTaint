pragma solidity 0.8.17;
import {UUPSUpgradeableBase} from "../UUPSUpgradeableBase.sol";
import {IProtectionPoolCycleManager, ProtectionPoolCycleParams, ProtectionPoolCycle, ProtectionPoolCycleState} from "../interfaces/IProtectionPoolCycleManager.sol";
import "../libraries/Constants.sol";
contract ProtectionPoolCycleManager is
  UUPSUpgradeableBase,
  IProtectionPoolCycleManager
{
  address public contractFactoryAddress;
  mapping(address => ProtectionPoolCycle) private protectionPoolCycles;
  modifier onlyContractFactory() {
    if (msg.sender != contractFactoryAddress) {
      revert NotContractFactory(msg.sender);
    }
    _;
  }
  function initialize() external initializer {
    __UUPSUpgradeableBase_init();
  }
  function setContractFactory(address _contractFactoryAddress)
    external
    payable
    override
    onlyOwner
  {
    if (_contractFactoryAddress == Constants.ZERO_ADDRESS) {
      revert ZeroContractFactoryAddress();
    }
    contractFactoryAddress = _contractFactoryAddress;
    emit ContractFactoryUpdated(_contractFactoryAddress);
  }
  function registerProtectionPool(
    address _poolAddress,
    ProtectionPoolCycleParams calldata _cycleParams
  ) external payable override onlyContractFactory {
    ProtectionPoolCycle storage poolCycle = protectionPoolCycles[_poolAddress];
    if (poolCycle.currentCycleStartTime > 0) {
      revert ProtectionPoolAlreadyRegistered(_poolAddress);
    }
    if (_cycleParams.openCycleDuration > _cycleParams.cycleDuration) {
      revert InvalidCycleDuration(_cycleParams.cycleDuration);
    }
    poolCycle.params = _cycleParams;
    _startNewCycle(_poolAddress, poolCycle, 0);
  }
  function calculateAndSetPoolCycleState(address _protectionPoolAddress)
    external
    override
    returns (ProtectionPoolCycleState _newState)
  {
    ProtectionPoolCycle storage poolCycle = protectionPoolCycles[
      _protectionPoolAddress
    ];
    ProtectionPoolCycleState currentState = _newState = poolCycle
      .currentCycleState;
    if (currentState == ProtectionPoolCycleState.None) {
      return _newState;
    }
    if (currentState == ProtectionPoolCycleState.Open) {
      if (
        block.timestamp - poolCycle.currentCycleStartTime >
        poolCycle.params.openCycleDuration
      ) {
        poolCycle.currentCycleState = _newState = ProtectionPoolCycleState
          .Locked;
      }
    }
    else if (currentState == ProtectionPoolCycleState.Locked) {
      if (
        block.timestamp - poolCycle.currentCycleStartTime >
        poolCycle.params.cycleDuration
      ) {
        _startNewCycle(
          _protectionPoolAddress,
          poolCycle,
          poolCycle.currentCycleIndex + 1
        );
        _newState = ProtectionPoolCycleState.Open;
      }
    }
    return _newState;
  }
  function getCurrentCycleState(address _poolAddress)
    external
    view
    override
    returns (ProtectionPoolCycleState)
  {
    return protectionPoolCycles[_poolAddress].currentCycleState;
  }
  function getCurrentCycleIndex(address _poolAddress)
    external
    view
    override
    returns (uint256)
  {
    return protectionPoolCycles[_poolAddress].currentCycleIndex;
  }
  function getCurrentPoolCycle(address _poolAddress)
    external
    view
    override
    returns (ProtectionPoolCycle memory)
  {
    return protectionPoolCycles[_poolAddress];
  }
  function getNextCycleEndTimestamp(address _poolAddress)
    external
    view
    override
    returns (uint256)
  {
    ProtectionPoolCycle storage poolCycle = protectionPoolCycles[_poolAddress];
    return
      poolCycle.currentCycleStartTime + (2 * poolCycle.params.cycleDuration);
  }
  function _startNewCycle(
    address _protectionPoolAddress,
    ProtectionPoolCycle storage _poolCycle,
    uint256 _cycleIndex
  ) internal {
    _poolCycle.currentCycleIndex = _cycleIndex;
    _poolCycle.currentCycleStartTime = block.timestamp;
    _poolCycle.currentCycleState = ProtectionPoolCycleState.Open;
    emit ProtectionPoolCycleCreated(
      _protectionPoolAddress,
      _cycleIndex,
      block.timestamp,
      _poolCycle.params.openCycleDuration,
      _poolCycle.params.cycleDuration
    );
  }
}