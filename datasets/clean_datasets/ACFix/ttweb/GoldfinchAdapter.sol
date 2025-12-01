pragma solidity 0.8.17;
import "@prb/math/contracts/PRBMathUD60x18.sol";
import {UUPSUpgradeableBase} from "../UUPSUpgradeableBase.sol";
import {IPoolTokens} from "../external/goldfinch/IPoolTokens.sol";
import {ITranchedPool} from "../external/goldfinch/ITranchedPool.sol";
import {ICreditLine} from "../external/goldfinch/ICreditLine.sol";
import {IGoldfinchConfig} from "../external/goldfinch/IGoldfinchConfig.sol";
import {ConfigOptions} from "../external/goldfinch/ConfigOptions.sol";
import {ISeniorPoolStrategy} from "../external/goldfinch/ISeniorPoolStrategy.sol";
import {ISeniorPool} from "../external/goldfinch/ISeniorPool.sol";
import {ILendingProtocolAdapter} from "../interfaces/ILendingProtocolAdapter.sol";
import {IReferenceLendingPools, ProtectionPurchaseParams} from "../interfaces/IReferenceLendingPools.sol";
import "../libraries/Constants.sol";
contract GoldfinchAdapter is UUPSUpgradeableBase, ILendingProtocolAdapter {
  using PRBMathUD60x18 for uint256;
  uint256 private constant NUM_TRANCHES_PER_SLICE = 2;
  address private constant GOLDFINCH_CONFIG_ADDRESS =
    0xaA425F8BfE82CD18f634e2Fe91E5DdEeFD98fDA1;
  IGoldfinchConfig private goldfinchConfig;
  function initialize(address _owner) external initializer {
    __UUPSUpgradeableBase_init();
    _transferOwnership(_owner);
    goldfinchConfig = IGoldfinchConfig(GOLDFINCH_CONFIG_ADDRESS);
  }
  function isLendingPoolExpired(address _lendingPoolAddress)
    external
    view
    override
    returns (bool)
  {
    ICreditLine _creditLine = _getCreditLine(_lendingPoolAddress);
    uint256 _termEndTimestamp = _creditLine.termEndTime();
    return
      block.timestamp >= _termEndTimestamp ||
      (_termEndTimestamp > 0 && _creditLine.balance() == 0);
  }
  function isLendingPoolLate(address _lendingPoolAddress)
    external
    view
    override
    returns (bool)
  {
    return _isLendingPoolLate(_lendingPoolAddress);
  }
  function isLendingPoolLateWithinGracePeriod(
    address _lendingPoolAddress,
    uint256 _gracePeriodInDays
  ) external view override returns (bool) {
    uint256 _lastPaymentTimestamp = _getLatestPaymentTimestamp(
      _lendingPoolAddress
    );
    return
      _isLendingPoolLate(_lendingPoolAddress) &&
      block.timestamp <=
      (_lastPaymentTimestamp +
        ((_getCreditLine(_lendingPoolAddress).paymentPeriodInDays() +
          _gracePeriodInDays) * Constants.SECONDS_IN_DAY_UINT));
  }
  function getLendingPoolTermEndTimestamp(address _lendingPoolAddress)
    external
    view
    override
    returns (uint256 _termEndTimestamp)
  {
    _termEndTimestamp = _getCreditLine(_lendingPoolAddress).termEndTime();
  }
  function calculateProtectionBuyerAPR(address _lendingPoolAddress)
    external
    view
    override
    returns (uint256 _interestRate)
  {
    ITranchedPool _tranchedPool = ITranchedPool(_lendingPoolAddress);
    ICreditLine _creditLine = _tranchedPool.creditLine();
    uint256 _loanInterestRate = _creditLine.interestApr();
    uint256 _protocolFeePercent = _getProtocolFeePercent();
    uint256 _juniorReallocationPercent = (_tranchedPool.juniorFeePercent() *
      Constants.SCALE_18_DECIMALS) / 100;
    uint256 _leverageRatio = _getLeverageRatio(_tranchedPool);
    _interestRate = _loanInterestRate.mul(
      Constants.SCALE_18_DECIMALS -
        _protocolFeePercent +
        _leverageRatio.mul(_juniorReallocationPercent)
    );
  }
  function calculateRemainingPrincipal(
    address _lendingPoolAddress,
    address _lender,
    uint256 _nftLpTokenId
  ) public view override returns (uint256 _principalRemaining) {
    IPoolTokens _poolTokens = _getPoolTokens();
    if (_poolTokens.ownerOf(_nftLpTokenId) == _lender) {
      IPoolTokens.TokenInfo memory _tokenInfo = _poolTokens.getTokenInfo(
        _nftLpTokenId
      );
      if (
        _tokenInfo.pool == _lendingPoolAddress &&
        _isJuniorTrancheId(_tokenInfo.tranche)
      ) {
        _principalRemaining =
          _tokenInfo.principalAmount -
          _tokenInfo.principalRedeemed;
      }
    }
  }
  function getPaymentPeriodInDays(address _lendingPool)
    public
    view
    override
    returns (uint256)
  {
    return _getCreditLine(_lendingPool).paymentPeriodInDays();
  }
  function getLatestPaymentTimestamp(address _lendingPool)
    public
    view
    override
    returns (uint256)
  {
    return _getLatestPaymentTimestamp(_lendingPool);
  }
  function _isJuniorTrancheId(uint256 trancheId) internal pure returns (bool) {
    return trancheId != 0 && (trancheId % NUM_TRANCHES_PER_SLICE) == 0;
  }
  function _getProtocolFeePercent()
    internal
    view
    returns (uint256 _feePercent)
  {
    uint256 reserveDenominator = goldfinchConfig.getNumber(
      uint256(ConfigOptions.Numbers.ReserveDenominator)
    );
    _feePercent = Constants.SCALE_18_DECIMALS / reserveDenominator;
  }
  function _getLeverageRatio(ITranchedPool _tranchedPool)
    internal
    view
    returns (uint256 _leverageRatio)
  {
    ISeniorPoolStrategy _seniorPoolStrategy = ISeniorPoolStrategy(
      goldfinchConfig.getAddress(
        uint256(ConfigOptions.Addresses.SeniorPoolStrategy)
      )
    );
    return _seniorPoolStrategy.getLeverageRatio(_tranchedPool);
  }
  function _getPoolTokens() internal view returns (IPoolTokens) {
    return
      IPoolTokens(
        goldfinchConfig.getAddress(uint256(ConfigOptions.Addresses.PoolTokens))
      );
  }
  function _getCreditLine(address _lendingPoolAddress)
    internal
    view
    returns (ICreditLine)
  {
    return ITranchedPool(_lendingPoolAddress).creditLine();
  }
  function _getLatestPaymentTimestamp(address _lendingPool)
    internal
    view
    returns (uint256)
  {
    return _getCreditLine(_lendingPool).lastFullPaymentTime();
  }
  function _isLendingPoolLate(address _lendingPoolAddress)
    internal
    view
    returns (bool)
  {
    return _getCreditLine(_lendingPoolAddress).isLate();
  }
}