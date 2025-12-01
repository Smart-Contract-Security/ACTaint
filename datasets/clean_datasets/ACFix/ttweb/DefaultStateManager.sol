pragma solidity 0.8.17;
import {ERC20SnapshotUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import {UUPSUpgradeableBase} from "../UUPSUpgradeableBase.sol";
import {IReferenceLendingPools, LendingPoolStatus} from "../interfaces/IReferenceLendingPools.sol";
import {ILendingProtocolAdapter} from "../interfaces/ILendingProtocolAdapter.sol";
import {IProtectionPool} from "../interfaces/IProtectionPool.sol";
import {IDefaultStateManager, ProtectionPoolState, LockedCapital, LendingPoolStatusDetail} from "../interfaces/IDefaultStateManager.sol";
import "../libraries/Constants.sol";
import "hardhat/console.sol";
contract DefaultStateManager is UUPSUpgradeableBase, IDefaultStateManager {
  address public contractFactoryAddress;
  ProtectionPoolState[] private protectionPoolStates;
  mapping(address => uint256) private protectionPoolStateIndexes;
  modifier onlyContractFactory() {
    if (msg.sender != contractFactoryAddress) {
      revert NotContractFactory(msg.sender);
    }
    _;
  }
  function initialize() external initializer {
    __UUPSUpgradeableBase_init();
    protectionPoolStates.push();
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
  function registerProtectionPool(address _protectionPoolAddress)
    external
    payable
    override
    onlyContractFactory
  {
    if (
      protectionPoolStates[protectionPoolStateIndexes[_protectionPoolAddress]]
        .updatedTimestamp > 0
    ) {
      revert ProtectionPoolAlreadyRegistered(_protectionPoolAddress);
    }
    uint256 newIndex = protectionPoolStates.length;
    protectionPoolStates.push();
    ProtectionPoolState storage poolState = protectionPoolStates[newIndex];
    poolState.protectionPool = IProtectionPool(_protectionPoolAddress);
    protectionPoolStateIndexes[_protectionPoolAddress] = newIndex;
    _assessState(poolState);
    emit ProtectionPoolRegistered(_protectionPoolAddress);
  }
  function assessStates() external override {
    uint256 _length = protectionPoolStates.length;
    for (uint256 _poolIndex = 1; _poolIndex < _length; ) {
      _assessState(protectionPoolStates[_poolIndex]);
      unchecked {
        ++_poolIndex;
      }
    }
    emit ProtectionPoolStatesAssessed();
  }
  function assessStateBatch(address[] calldata _pools) external override {
    uint256 _length = _pools.length;
    for (uint256 _poolIndex; _poolIndex < _length; ) {
      ProtectionPoolState storage poolState = protectionPoolStates[
        protectionPoolStateIndexes[_pools[_poolIndex]]
      ];
      if (poolState.updatedTimestamp > 0) {
        _assessState(poolState);
      }
      unchecked {
        ++_poolIndex;
      }
    }
  }
  function calculateAndClaimUnlockedCapital(address _seller)
    external
    override
    returns (uint256 _claimedUnlockedCapital)
  {
    ProtectionPoolState storage poolState = protectionPoolStates[
      protectionPoolStateIndexes[msg.sender]
    ];
    if (poolState.updatedTimestamp == 0) {
      revert ProtectionPoolNotRegistered(msg.sender);
    }
    address[] memory _lendingPools = poolState
      .protectionPool
      .getPoolInfo()
      .referenceLendingPools
      .getLendingPools();
    uint256 _length = _lendingPools.length;
    for (uint256 _lendingPoolIndex; _lendingPoolIndex < _length; ) {
      address _lendingPool = _lendingPools[_lendingPoolIndex];
      (
        uint256 _unlockedCapitalPerLendingPool,
        uint256 _snapshotId
      ) = _calculateClaimableAmount(poolState, _lendingPool, _seller);
      _claimedUnlockedCapital += _unlockedCapitalPerLendingPool;
      poolState.lastClaimedSnapshotIds[_lendingPool][_seller] = _snapshotId;
      unchecked {
        ++_lendingPoolIndex;
      }
    }
  }
  function getPoolStateUpdateTimestamp(address _pool)
    external
    view
    returns (uint256)
  {
    return
      protectionPoolStates[protectionPoolStateIndexes[_pool]].updatedTimestamp;
  }
  function getLockedCapitals(address _protectionPool, address _lendingPool)
    external
    view
    returns (LockedCapital[] memory _lockedCapitals)
  {
    ProtectionPoolState storage poolState = protectionPoolStates[
      protectionPoolStateIndexes[_protectionPool]
    ];
    _lockedCapitals = poolState.lockedCapitals[_lendingPool];
  }
  function calculateClaimableUnlockedAmount(
    address _protectionPool,
    address _seller
  ) external view override returns (uint256 _claimableUnlockedCapital) {
    ProtectionPoolState storage poolState = protectionPoolStates[
      protectionPoolStateIndexes[_protectionPool]
    ];
    if (poolState.updatedTimestamp > 0) {
      address[] memory _lendingPools = poolState
        .protectionPool
        .getPoolInfo()
        .referenceLendingPools
        .getLendingPools();
      uint256 _length = _lendingPools.length;
      for (uint256 _lendingPoolIndex; _lendingPoolIndex < _length; ) {
        address _lendingPool = _lendingPools[_lendingPoolIndex];
        (uint256 _unlockedCapitalPerLendingPool, ) = _calculateClaimableAmount(
          poolState,
          _lendingPool,
          _seller
        );
        _claimableUnlockedCapital += _unlockedCapitalPerLendingPool;
        unchecked {
          ++_lendingPoolIndex;
        }
      }
    }
  }
  function getLendingPoolStatus(
    address _protectionPoolAddress,
    address _lendingPoolAddress
  ) external view override returns (LendingPoolStatus) {
    return
      protectionPoolStates[protectionPoolStateIndexes[_protectionPoolAddress]]
        .lendingPoolStateDetails[_lendingPoolAddress]
        .currentStatus;
  }
  function _assessState(ProtectionPoolState storage poolState) internal {
    poolState.updatedTimestamp = block.timestamp;
    (
      address[] memory _lendingPools,
      LendingPoolStatus[] memory _currentStatuses
    ) = poolState
        .protectionPool
        .getPoolInfo()
        .referenceLendingPools
        .assessState();
    uint256 _length = _lendingPools.length;
    for (uint256 _lendingPoolIndex; _lendingPoolIndex < _length; ) {
      address _lendingPool = _lendingPools[_lendingPoolIndex];
      LendingPoolStatusDetail storage lendingPoolStateDetail = poolState
        .lendingPoolStateDetails[_lendingPool];
      LendingPoolStatus _previousStatus = lendingPoolStateDetail.currentStatus;
      LendingPoolStatus _currentStatus = _currentStatuses[_lendingPoolIndex];
      if (_previousStatus != _currentStatus) {
        console.log(
          "DefaultStateManager: Lending pool %s status is changed from %s to  %s",
          _lendingPool,
          uint256(_previousStatus),
          uint256(_currentStatus)
        );
      }
      if (
        (_previousStatus == LendingPoolStatus.Active ||
          _previousStatus == LendingPoolStatus.LateWithinGracePeriod) &&
        _currentStatus == LendingPoolStatus.Late
      ) {
        lendingPoolStateDetail.currentStatus = LendingPoolStatus.Late;
        _moveFromActiveToLockedState(poolState, _lendingPool);
        lendingPoolStateDetail.lateTimestamp = block.timestamp;
      } else if (_previousStatus == LendingPoolStatus.Late) {
        if (
          block.timestamp >
          (lendingPoolStateDetail.lateTimestamp +
            _getTwoPaymentPeriodsInSeconds(poolState, _lendingPool))
        ) {
          if (_currentStatus == LendingPoolStatus.Active) {
            lendingPoolStateDetail.currentStatus = LendingPoolStatus.Active;
            _moveFromLockedToActiveState(poolState, _lendingPool);
            lendingPoolStateDetail.lateTimestamp = 0;
          }
          else if (_currentStatus == LendingPoolStatus.Late) {
            lendingPoolStateDetail.currentStatus = LendingPoolStatus.Defaulted;
          }
        }
      } else if (
        _previousStatus == LendingPoolStatus.Defaulted ||
        _previousStatus == LendingPoolStatus.Expired
      ) {
      } else {
        if (_previousStatus != _currentStatus) {
          lendingPoolStateDetail.currentStatus = _currentStatus;
        }
      }
      unchecked {
        ++_lendingPoolIndex;
      }
    }
  }
  function _moveFromActiveToLockedState(
    ProtectionPoolState storage poolState,
    address _lendingPool
  ) internal {
    IProtectionPool _protectionPool = poolState.protectionPool;
    (uint256 _lockedCapital, uint256 _snapshotId) = _protectionPool.lockCapital(
      _lendingPool
    );
    poolState.lockedCapitals[_lendingPool].push(
      LockedCapital({
        snapshotId: _snapshotId,
        amount: _lockedCapital,
        locked: true
      })
    );
    emit LendingPoolLocked(
      _lendingPool,
      address(_protectionPool),
      _snapshotId,
      _lockedCapital
    );
  }
  function _moveFromLockedToActiveState(
    ProtectionPoolState storage poolState,
    address _lendingPool
  ) internal {
    LockedCapital storage lockedCapital = _getLatestLockedCapital(
      poolState,
      _lendingPool
    );
    lockedCapital.locked = false;
    emit LendingPoolUnlocked(
      _lendingPool,
      address(poolState.protectionPool),
      lockedCapital.amount
    );
  }
  function _calculateClaimableAmount(
    ProtectionPoolState storage poolState,
    address _lendingPool,
    address _seller
  )
    internal
    view
    returns (
      uint256 _claimableUnlockedCapital,
      uint256 _latestClaimedSnapshotId
    )
  {
    uint256 _lastClaimedSnapshotId = poolState.lastClaimedSnapshotIds[
      _lendingPool
    ][_seller];
    LockedCapital[] storage lockedCapitals = poolState.lockedCapitals[
      _lendingPool
    ];
    uint256 _length = lockedCapitals.length;
    for (uint256 _index = 0; _index < _length; ) {
      LockedCapital storage lockedCapital = lockedCapitals[_index];
      uint256 _snapshotId = lockedCapital.snapshotId;
      console.log(
        "lockedCapital.locked: %s, amt: %s",
        lockedCapital.locked,
        lockedCapital.amount
      );
      if (!lockedCapital.locked && _snapshotId > _lastClaimedSnapshotId) {
        ERC20SnapshotUpgradeable _poolSToken = ERC20SnapshotUpgradeable(
          address(poolState.protectionPool)
        );
        console.log(
          "balance of seller: %s, total supply: %s at snapshot: %s",
          _poolSToken.balanceOfAt(_seller, _snapshotId),
          _poolSToken.totalSupplyAt(_snapshotId),
          _snapshotId
        );
        _claimableUnlockedCapital =
          (_poolSToken.balanceOfAt(_seller, _snapshotId) *
            lockedCapital.amount) /
          _poolSToken.totalSupplyAt(_snapshotId);
        _latestClaimedSnapshotId = _snapshotId;
        console.log(
          "Claimable amount for seller %s is %s",
          _seller,
          _claimableUnlockedCapital
        );
      }
      unchecked {
        ++_index;
      }
    }
  }
  function _getLatestLockedCapital(
    ProtectionPoolState storage poolState,
    address _lendingPool
  ) internal view returns (LockedCapital storage _lockedCapital) {
    LockedCapital[] storage lockedCapitals = poolState.lockedCapitals[
      _lendingPool
    ];
    _lockedCapital = lockedCapitals[lockedCapitals.length - 1];
  }
  function _getTwoPaymentPeriodsInSeconds(
    ProtectionPoolState storage poolState,
    address _lendingPool
  ) internal view returns (uint256) {
    return
      (poolState
        .protectionPool
        .getPoolInfo()
        .referenceLendingPools
        .getPaymentPeriodInDays(_lendingPool) * 2) *
      Constants.SECONDS_IN_DAY_UINT;
  }
}