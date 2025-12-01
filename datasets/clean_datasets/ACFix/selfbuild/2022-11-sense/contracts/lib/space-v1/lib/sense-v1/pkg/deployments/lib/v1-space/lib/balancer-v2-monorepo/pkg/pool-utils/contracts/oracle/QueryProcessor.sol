pragma solidity ^0.7.0;
pragma experimental ABIEncoderV2;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/BalancerErrors.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/LogCompression.sol";
import "../interfaces/IPriceOracle.sol";
import "./Buffer.sol";
import "./Samples.sol";
library QueryProcessor {
    using Buffer for uint256;
    using Samples for bytes32;
    using LogCompression for int256;
    function getInstantValue(
        mapping(uint256 => bytes32) storage samples,
        IPriceOracle.Variable variable,
        uint256 index
    ) external view returns (uint256) {
        bytes32 sample = samples[index];
        _require(sample.timestamp() > 0, Errors.ORACLE_NOT_INITIALIZED);
        int256 rawInstantValue = sample.instant(variable);
        return LogCompression.fromLowResLog(rawInstantValue);
    }
    function getTimeWeightedAverage(
        mapping(uint256 => bytes32) storage samples,
        IPriceOracle.OracleAverageQuery memory query,
        uint256 latestIndex
    ) external view returns (uint256) {
        _require(query.secs != 0, Errors.ORACLE_BAD_SECS);
        int256 beginAccumulator = getPastAccumulator(samples, query.variable, latestIndex, query.ago + query.secs);
        int256 endAccumulator = getPastAccumulator(samples, query.variable, latestIndex, query.ago);
        return LogCompression.fromLowResLog((endAccumulator - beginAccumulator) / int256(query.secs));
    }
    function getPastAccumulator(
        mapping(uint256 => bytes32) storage samples,
        IPriceOracle.Variable variable,
        uint256 latestIndex,
        uint256 ago
    ) public view returns (int256) {
        _require(block.timestamp >= ago, Errors.ORACLE_INVALID_SECONDS_QUERY);
        uint256 lookUpTime = block.timestamp - ago;
        bytes32 latestSample = samples[latestIndex];
        uint256 latestTimestamp = latestSample.timestamp();
        _require(latestTimestamp > 0, Errors.ORACLE_NOT_INITIALIZED);
        if (latestTimestamp <= lookUpTime) {
            uint256 elapsed = lookUpTime - latestTimestamp;
            return latestSample.accumulator(variable) + (latestSample.instant(variable) * int256(elapsed));
        } else {
            uint256 bufferLength;
            uint256 oldestIndex = latestIndex.next();
            {
                bytes32 oldestSample = samples[oldestIndex];
                uint256 oldestTimestamp = oldestSample.timestamp();
                if (oldestTimestamp > 0) {
                    bufferLength = Buffer.SIZE;
                } else {
                    bufferLength = oldestIndex; 
                    oldestIndex = 0;
                    oldestTimestamp = samples[0].timestamp();
                }
                _require(oldestTimestamp <= lookUpTime, Errors.ORACLE_QUERY_TOO_OLD);
            }
            (bytes32 prev, bytes32 next) = findNearestSample(samples, lookUpTime, oldestIndex, bufferLength);
            uint256 samplesTimeDiff = next.timestamp() - prev.timestamp();
            if (samplesTimeDiff > 0) {
                int256 samplesAccDiff = next.accumulator(variable) - prev.accumulator(variable);
                uint256 elapsed = lookUpTime - prev.timestamp();
                return prev.accumulator(variable) + ((samplesAccDiff * int256(elapsed)) / int256(samplesTimeDiff));
            } else {
                return prev.accumulator(variable);
            }
        }
    }
    function findNearestSample(
        mapping(uint256 => bytes32) storage samples,
        uint256 lookUpDate,
        uint256 offset,
        uint256 length
    ) public view returns (bytes32 prev, bytes32 next) {
        uint256 low = 0;
        uint256 high = length - 1;
        uint256 mid;
        bytes32 sample;
        uint256 sampleTimestamp;
        while (low <= high) {
            uint256 midWithoutOffset = (high + low) / 2;
            mid = midWithoutOffset.add(offset);
            sample = samples[mid];
            sampleTimestamp = sample.timestamp();
            if (sampleTimestamp < lookUpDate) {
                low = midWithoutOffset + 1;
            } else if (sampleTimestamp > lookUpDate) {
                high = midWithoutOffset - 1;
            } else {
                return (sample, sample);
            }
        }
        return sampleTimestamp < lookUpDate ? (sample, samples[mid.next()]) : (samples[mid.prev()], sample);
    }
}