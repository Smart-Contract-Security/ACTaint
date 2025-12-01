pragma solidity =0.7.6;
pragma abicoder v2;
import '@openzeppelin/contracts/utils/Address.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '../interfaces/IStaticOracle.sol';
contract StaticOracle is IStaticOracle {
  IUniswapV3Factory public immutable override UNISWAP_V3_FACTORY;
  uint8 public immutable override CARDINALITY_PER_MINUTE;
  uint24[] internal _knownFeeTiers;
  constructor(IUniswapV3Factory _UNISWAP_V3_FACTORY, uint8 _CARDINALITY_PER_MINUTE) {
    UNISWAP_V3_FACTORY = _UNISWAP_V3_FACTORY;
    CARDINALITY_PER_MINUTE = _CARDINALITY_PER_MINUTE;
    _knownFeeTiers.push(500);
    _knownFeeTiers.push(3000);
    _knownFeeTiers.push(10000);
  }
  function supportedFeeTiers() external view override returns (uint24[] memory) {
    return _knownFeeTiers;
  }
  function isPairSupported(address _tokenA, address _tokenB) external view override returns (bool) {
    uint256 _length = _knownFeeTiers.length;
    for (uint256 i; i < _length; ++i) {
      address _pool = PoolAddress.computeAddress(address(UNISWAP_V3_FACTORY), PoolAddress.getPoolKey(_tokenA, _tokenB, _knownFeeTiers[i]));
      if (Address.isContract(_pool)) {
        return true;
      }
    }
    return false;
  }
  function getAllPoolsForPair(address _tokenA, address _tokenB) public view override returns (address[] memory) {
    return _getPoolsForTiers(_tokenA, _tokenB, _knownFeeTiers);
  }
  function quoteAllAvailablePoolsWithTimePeriod(
    uint128 _baseAmount,
    address _baseToken,
    address _quoteToken,
    uint32 _period
  ) external view override returns (uint256 _quoteAmount, address[] memory _queriedPools) {
    _queriedPools = _getQueryablePoolsForTiers(_baseToken, _quoteToken, _period);
    _quoteAmount = _quote(_baseAmount, _baseToken, _quoteToken, _queriedPools, _period);
  }
  function quoteSpecificFeeTiersWithTimePeriod(
    uint128 _baseAmount,
    address _baseToken,
    address _quoteToken,
    uint24[] calldata _feeTiers,
    uint32 _period
  ) external view override returns (uint256 _quoteAmount, address[] memory _queriedPools) {
    _queriedPools = _getPoolsForTiers(_baseToken, _quoteToken, _feeTiers);
    require(_queriedPools.length == _feeTiers.length, 'Given tier does not have pool');
    _quoteAmount = _quote(_baseAmount, _baseToken, _quoteToken, _queriedPools, _period);
  }
  function quoteSpecificPoolsWithTimePeriod(
    uint128 _baseAmount,
    address _baseToken,
    address _quoteToken,
    address[] calldata _pools,
    uint32 _period
  ) external view override returns (uint256 _quoteAmount) {
    return _quote(_baseAmount, _baseToken, _quoteToken, _pools, _period);
  }
  function prepareAllAvailablePoolsWithTimePeriod(
    address _tokenA,
    address _tokenB,
    uint32 _period
  ) external override returns (address[] memory _preparedPools) {
    return prepareAllAvailablePoolsWithCardinality(_tokenA, _tokenB, _getCardinalityForTimePeriod(_period));
  }
  function prepareSpecificFeeTiersWithTimePeriod(
    address _tokenA,
    address _tokenB,
    uint24[] calldata _feeTiers,
    uint32 _period
  ) external override returns (address[] memory _preparedPools) {
    return prepareSpecificFeeTiersWithCardinality(_tokenA, _tokenB, _feeTiers, _getCardinalityForTimePeriod(_period));
  }
  function prepareSpecificPoolsWithTimePeriod(address[] calldata _pools, uint32 _period) external override {
    prepareSpecificPoolsWithCardinality(_pools, _getCardinalityForTimePeriod(_period));
  }
  function prepareAllAvailablePoolsWithCardinality(
    address _tokenA,
    address _tokenB,
    uint16 _cardinality
  ) public override returns (address[] memory _preparedPools) {
    _preparedPools = getAllPoolsForPair(_tokenA, _tokenB);
    _prepare(_preparedPools, _cardinality);
  }
  function prepareSpecificFeeTiersWithCardinality(
    address _tokenA,
    address _tokenB,
    uint24[] calldata _feeTiers,
    uint16 _cardinality
  ) public override returns (address[] memory _preparedPools) {
    _preparedPools = _getPoolsForTiers(_tokenA, _tokenB, _feeTiers);
    require(_preparedPools.length == _feeTiers.length, 'Given tier does not have pool');
    _prepare(_preparedPools, _cardinality);
  }
  function prepareSpecificPoolsWithCardinality(address[] calldata _pools, uint16 _cardinality) public override {
    _prepare(_pools, _cardinality);
  }
  function addNewFeeTier(uint24 _feeTier) external override {
    require(UNISWAP_V3_FACTORY.feeAmountTickSpacing(_feeTier) != 0, 'Invalid fee tier');
    for (uint256 i; i < _knownFeeTiers.length; i++) {
      require(_knownFeeTiers[i] != _feeTier, 'Tier already supported');
    }
    _knownFeeTiers.push(_feeTier);
  }
  function _getCardinalityForTimePeriod(uint32 _period) internal view returns (uint16 _cardinality) {
    _cardinality = uint16((_period * CARDINALITY_PER_MINUTE) / 60) + 1;
  }
  function _prepare(address[] memory _pools, uint16 _cardinality) internal {
    for (uint256 i; i < _pools.length; i++) {
      IUniswapV3Pool(_pools[i]).increaseObservationCardinalityNext(_cardinality);
    }
  }
  function _quote(
    uint128 _baseAmount,
    address _baseToken,
    address _quoteToken,
    address[] memory _pools,
    uint32 _period
  ) internal view returns (uint256 _quoteAmount) {
    require(_pools.length > 0, 'No defined pools');
    OracleLibrary.WeightedTickData[] memory _tickData = new OracleLibrary.WeightedTickData[](_pools.length);
    for (uint256 i; i < _pools.length; i++) {
      (_tickData[i].tick, _tickData[i].weight) = _period > 0
        ? OracleLibrary.consult(_pools[i], _period)
        : OracleLibrary.getBlockStartingTickAndLiquidity(_pools[i]);
    }
    int24 _weightedTick = _tickData.length == 1 ? _tickData[0].tick : OracleLibrary.getWeightedArithmeticMeanTick(_tickData);
    return OracleLibrary.getQuoteAtTick(_weightedTick, _baseAmount, _baseToken, _quoteToken);
  }
  function _getQueryablePoolsForTiers(
    address _tokenA,
    address _tokenB,
    uint32 _period
  ) internal view virtual returns (address[] memory _queryablePools) {
    address[] memory _existingPools = getAllPoolsForPair(_tokenA, _tokenB);
    if (_period == 0) return _existingPools;
    _queryablePools = new address[](_existingPools.length);
    uint256 _validPools;
    for (uint256 i; i < _existingPools.length; i++) {
      if (OracleLibrary.getOldestObservationSecondsAgo(_existingPools[i]) >= _period) {
        _queryablePools[_validPools++] = _existingPools[i];
      }
    }
    _resizeArray(_queryablePools, _validPools);
  }
  function _getPoolsForTiers(
    address _tokenA,
    address _tokenB,
    uint24[] memory _feeTiers
  ) internal view virtual returns (address[] memory _pools) {
    _pools = new address[](_feeTiers.length);
    uint256 _validPools;
    for (uint256 i; i < _feeTiers.length; i++) {
      address _pool = PoolAddress.computeAddress(address(UNISWAP_V3_FACTORY), PoolAddress.getPoolKey(_tokenA, _tokenB, _feeTiers[i]));
      if (Address.isContract(_pool)) {
        _pools[_validPools++] = _pool;
      }
    }
    _resizeArray(_pools, _validPools);
  }
  function _resizeArray(address[] memory _array, uint256 _amountOfValidElements) internal pure {
    if (_array.length == _amountOfValidElements) return;
    assembly {
      mstore(_array, _amountOfValidElements)
    }
  }
}