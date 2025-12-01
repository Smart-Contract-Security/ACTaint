pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/BalancerErrors.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IPoolPriceOracle.sol";
import "./Buffer.sol";
import "./Samples.sol";
import "./QueryProcessor.sol";
abstract contract PoolPriceOracle is IPoolPriceOracle, IPriceOracle {
    using Buffer for uint256;
    using Samples for bytes32;
    uint256 private constant _MAX_SAMPLE_DURATION = 2 minutes;
    mapping(uint256 => bytes32) internal _samples;
    function getSample(uint256 index)
        external
        view
        override
        returns (
            int256 logPairPrice,
            int256 accLogPairPrice,
            int256 logBptPrice,
            int256 accLogBptPrice,
            int256 logInvariant,
            int256 accLogInvariant,
            uint256 timestamp
        )
    {
        _require(index < Buffer.SIZE, Errors.ORACLE_INVALID_INDEX);
        bytes32 sample = _getSample(index);
        return sample.unpack();
    }
    function getTotalSamples() external pure override returns (uint256) {
        return Buffer.SIZE;
    }
    function dirtyUninitializedOracleSamples(uint256 startIndex, uint256 endIndex) external {
        _require(startIndex < endIndex && endIndex <= Buffer.SIZE, Errors.OUT_OF_BOUNDS);
        bytes32 initSample = Samples.pack(1, 0, 0, 0, 0, 0, 0);
        for (uint256 i = startIndex; i < endIndex; i++) {
            if (_samples[i].timestamp() == 0) {
                _samples[i] = initSample;
            }
        }
    }
    function getLargestSafeQueryWindow() external pure override returns (uint256) {
        return 34 hours;
    }
    function getLatest(Variable variable) external view override returns (uint256) {
        return QueryProcessor.getInstantValue(_samples, variable, _getOracleIndex());
    }
    function getTimeWeightedAverage(OracleAverageQuery[] memory queries)
        external
        view
        override
        returns (uint256[] memory results)
    {
        results = new uint256[](queries.length);
        uint256 latestIndex = _getOracleIndex();
        for (uint256 i = 0; i < queries.length; ++i) {
            results[i] = QueryProcessor.getTimeWeightedAverage(_samples, queries[i], latestIndex);
        }
    }
    function getPastAccumulators(OracleAccumulatorQuery[] memory queries)
        external
        view
        override
        returns (int256[] memory results)
    {
        results = new int256[](queries.length);
        uint256 latestIndex = _getOracleIndex();
        OracleAccumulatorQuery memory query;
        for (uint256 i = 0; i < queries.length; ++i) {
            query = queries[i];
            results[i] = _getPastAccumulator(query.variable, latestIndex, query.ago);
        }
    }
    function _processPriceData(
        uint256 latestSampleCreationTimestamp,
        uint256 latestIndex,
        int256 logPairPrice,
        int256 logBptPrice,
        int256 logInvariant
    ) internal returns (uint256) {
        bytes32 sample = _getSample(latestIndex).update(logPairPrice, logBptPrice, logInvariant, block.timestamp);
        bool newSample = block.timestamp - latestSampleCreationTimestamp >= _MAX_SAMPLE_DURATION;
        latestIndex = newSample ? latestIndex.next() : latestIndex;
        _samples[latestIndex] = sample;
        return latestIndex;
    }
    function _getPastAccumulator(
        IPriceOracle.Variable variable,
        uint256 latestIndex,
        uint256 ago
    ) internal view returns (int256) {
        return QueryProcessor.getPastAccumulator(_samples, variable, latestIndex, ago);
    }
    function _findNearestSample(
        uint256 lookUpDate,
        uint256 offset,
        uint256 length
    ) internal view returns (bytes32 prev, bytes32 next) {
        return QueryProcessor.findNearestSample(_samples, lookUpDate, offset, length);
    }
    function _getSample(uint256 index) internal view returns (bytes32) {
        return _samples[index];
    }
    function _getOracleIndex() internal view virtual returns (uint256);
}