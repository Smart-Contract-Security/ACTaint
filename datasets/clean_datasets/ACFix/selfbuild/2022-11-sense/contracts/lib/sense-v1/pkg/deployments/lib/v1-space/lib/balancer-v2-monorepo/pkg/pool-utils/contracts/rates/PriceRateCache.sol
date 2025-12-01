pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/helpers/WordCodec.sol";
import "@balancer-labs/v2-solidity-utils/contracts/helpers/BalancerErrors.sol";
library PriceRateCache {
    using WordCodec for bytes32;
    uint256 private constant _PRICE_RATE_CACHE_VALUE_OFFSET = 0;
    uint256 private constant _PRICE_RATE_CACHE_DURATION_OFFSET = 128;
    uint256 private constant _PRICE_RATE_CACHE_EXPIRES_OFFSET = 128 + 64;
    function getValue(bytes32 cache) internal pure returns (uint256) {
        return cache.decodeUint128(_PRICE_RATE_CACHE_VALUE_OFFSET);
    }
    function getDuration(bytes32 cache) internal pure returns (uint256) {
        return cache.decodeUint64(_PRICE_RATE_CACHE_DURATION_OFFSET);
    }
    function getTimestamps(bytes32 cache) internal pure returns (uint256 duration, uint256 expires) {
        duration = getDuration(cache);
        expires = cache.decodeUint64(_PRICE_RATE_CACHE_EXPIRES_OFFSET);
    }
    function encode(uint256 rate, uint256 duration) internal view returns (bytes32) {
        _require(rate < 2**128, Errors.PRICE_RATE_OVERFLOW);
        return
            WordCodec.encodeUint(uint128(rate), _PRICE_RATE_CACHE_VALUE_OFFSET) |
            WordCodec.encodeUint(uint64(duration), _PRICE_RATE_CACHE_DURATION_OFFSET) |
            WordCodec.encodeUint(uint64(block.timestamp + duration), _PRICE_RATE_CACHE_EXPIRES_OFFSET);
    }
    function decode(bytes32 cache)
        internal
        pure
        returns (
            uint256 rate,
            uint256 duration,
            uint256 expires
        )
    {
        rate = getValue(cache);
        (duration, expires) = getTimestamps(cache);
    }
}