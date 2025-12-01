pragma solidity 0.8.17;
import {UUPSUpgradeableBase} from "../../UUPSUpgradeableBase.sol";
import {IReferenceLendingPools, LendingPoolStatus, LendingProtocol, ProtectionPurchaseParams, ReferenceLendingPoolInfo} from "../../interfaces/IReferenceLendingPools.sol";
import {ILendingProtocolAdapter} from "../../interfaces/ILendingProtocolAdapter.sol";
import {ILendingProtocolAdapterFactory} from "../../interfaces/ILendingProtocolAdapterFactory.sol";
import "../../libraries/Constants.sol";
contract ReferenceLendingPools is UUPSUpgradeableBase, IReferenceLendingPools {
  ILendingProtocolAdapterFactory private lendingProtocolAdapterFactory;
  mapping(address => ReferenceLendingPoolInfo) public referenceLendingPools;
  address[] private lendingPools;
  modifier whenLendingPoolSupported(address _lendingPoolAddress) {
    if (!_isReferenceLendingPoolAdded(_lendingPoolAddress)) {
      revert ReferenceLendingPoolNotSupported(_lendingPoolAddress);
    }
    _;
  }
  function initialize(
    address _owner,
    address[] calldata _lendingPools,
    LendingProtocol[] calldata _lendingPoolProtocols,
    uint256[] calldata _protectionPurchaseLimitsInDays,
    address _lendingProtocolAdapterFactory
  ) external override initializer {
    if (
      _lendingPools.length != _lendingPoolProtocols.length ||
      _lendingPools.length != _protectionPurchaseLimitsInDays.length
    ) {
      revert ReferenceLendingPoolsConstructionError(
        "Array inputs length must match"
      );
    }
    if (_owner == Constants.ZERO_ADDRESS) {
      revert ReferenceLendingPoolsConstructionError(
        "Owner address must not be zero"
      );
    }
    __UUPSUpgradeableBase_init();
    lendingProtocolAdapterFactory = ILendingProtocolAdapterFactory(
      _lendingProtocolAdapterFactory
    );
    _transferOwnership(_owner);
    uint256 length = _lendingPools.length;
    for (uint256 i; i < length; ) {
      _addReferenceLendingPool(
        _lendingPools[i],
        _lendingPoolProtocols[i],
        _protectionPurchaseLimitsInDays[i]
      );
      unchecked {
        ++i;
      }
    }
  }
  function addReferenceLendingPool(
    address _lendingPoolAddress,
    LendingProtocol _lendingPoolProtocol,
    uint256 _protectionPurchaseLimitInDays
  ) external payable onlyOwner {
    _addReferenceLendingPool(
      _lendingPoolAddress,
      _lendingPoolProtocol,
      _protectionPurchaseLimitInDays
    );
  }
  function getLendingPools() public view override returns (address[] memory) {
    return lendingPools;
  }
  function canBuyProtection(
    address _buyer,
    ProtectionPurchaseParams calldata _purchaseParams,
    bool _isRenewal
  )
    external
    view
    override
    whenLendingPoolSupported(_purchaseParams.lendingPoolAddress)
    returns (bool)
  {
    ReferenceLendingPoolInfo storage lendingPoolInfo = referenceLendingPools[
      _purchaseParams.lendingPoolAddress
    ];
    if (
      !_isRenewal &&
      block.timestamp > lendingPoolInfo.protectionPurchaseLimitTimestamp
    ) {
      return false;
    }
    return
      _purchaseParams.protectionAmount <=
      calculateRemainingPrincipal(
        _purchaseParams.lendingPoolAddress,
        _buyer,
        _purchaseParams.nftLpTokenId
      );
  }
  function calculateProtectionBuyerAPR(address _lendingPoolAddress)
    public
    view
    override
    whenLendingPoolSupported(_lendingPoolAddress)
    returns (uint256)
  {
    return
      _getLendingProtocolAdapter(_lendingPoolAddress)
        .calculateProtectionBuyerAPR(_lendingPoolAddress);
  }
  function assessState()
    public
    view
    override
    returns (
      address[] memory _lendingPools,
      LendingPoolStatus[] memory _statuses
    )
  {
    uint256 _length = lendingPools.length;
    _lendingPools = new address[](_length);
    _statuses = new LendingPoolStatus[](_length);
    for (uint256 i; i < _length; ) {
      _lendingPools[i] = lendingPools[i];
      _statuses[i] = _getLendingPoolStatus(lendingPools[i]);
      unchecked {
        ++i;
      }
    }
  }
  function calculateRemainingPrincipal(
    address _lendingPool,
    address _lender,
    uint256 _nftLpTokenId
  )
    public
    view
    override
    whenLendingPoolSupported(_lendingPool)
    returns (uint256)
  {
    return
      _getLendingProtocolAdapter(_lendingPool).calculateRemainingPrincipal(
        _lendingPool,
        _lender,
        _nftLpTokenId
      );
  }
  function getLatestPaymentTimestamp(address _lendingPool)
    public
    view
    override
    returns (uint256)
  {
    return
      _getLendingProtocolAdapter(_lendingPool).getLatestPaymentTimestamp(
        _lendingPool
      );
  }
  function getPaymentPeriodInDays(address _lendingPool)
    public
    view
    override
    returns (uint256)
  {
    return
      _getLendingProtocolAdapter(_lendingPool).getPaymentPeriodInDays(
        _lendingPool
      );
  }
  function _addReferenceLendingPool(
    address _lendingPoolAddress,
    LendingProtocol _lendingPoolProtocol,
    uint256 _protectionPurchaseLimitInDays
  ) internal {
    if (_lendingPoolAddress == Constants.ZERO_ADDRESS) {
      revert ReferenceLendingPoolIsZeroAddress();
    }
    if (_isReferenceLendingPoolAdded(_lendingPoolAddress)) {
      revert ReferenceLendingPoolAlreadyAdded(_lendingPoolAddress);
    }
    uint256 _protectionPurchaseLimitTimestamp = block.timestamp +
      (_protectionPurchaseLimitInDays * Constants.SECONDS_IN_DAY_UINT);
    referenceLendingPools[_lendingPoolAddress] = ReferenceLendingPoolInfo({
      protocol: _lendingPoolProtocol,
      addedTimestamp: block.timestamp,
      protectionPurchaseLimitTimestamp: _protectionPurchaseLimitTimestamp
    });
    lendingPools.push(_lendingPoolAddress);
    LendingPoolStatus _poolStatus = _getLendingPoolStatus(_lendingPoolAddress);
    if (_poolStatus != LendingPoolStatus.Active) {
      revert ReferenceLendingPoolIsNotActive(_lendingPoolAddress);
    }
    emit ReferenceLendingPoolAdded(
      _lendingPoolAddress,
      _lendingPoolProtocol,
      block.timestamp,
      _protectionPurchaseLimitTimestamp
    );
  }
  function _getLendingProtocolAdapter(address _lendingPoolAddress)
    internal
    view
    returns (ILendingProtocolAdapter)
  {
    return
      lendingProtocolAdapterFactory.getLendingProtocolAdapter(
        referenceLendingPools[_lendingPoolAddress].protocol
      );
  }
  function _isReferenceLendingPoolAdded(address _lendingPoolAddress)
    internal
    view
    returns (bool)
  {
    return referenceLendingPools[_lendingPoolAddress].addedTimestamp != 0;
  }
  function _getLendingPoolStatus(address _lendingPoolAddress)
    internal
    view
    returns (LendingPoolStatus)
  {
    if (!_isReferenceLendingPoolAdded(_lendingPoolAddress)) {
      return LendingPoolStatus.NotSupported;
    }
    ILendingProtocolAdapter _adapter = _getLendingProtocolAdapter(
      _lendingPoolAddress
    );
    if (_adapter.isLendingPoolExpired(_lendingPoolAddress)) {
      return LendingPoolStatus.Expired;
    }
    if (
      _adapter.isLendingPoolLateWithinGracePeriod(
        _lendingPoolAddress,
        Constants.LATE_PAYMENT_GRACE_PERIOD_IN_DAYS
      )
    ) {
      return LendingPoolStatus.LateWithinGracePeriod;
    }
    if (_adapter.isLendingPoolLate(_lendingPoolAddress)) {
      return LendingPoolStatus.Late;
    }
    return LendingPoolStatus.Active;
  }
}