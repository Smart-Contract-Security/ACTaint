pragma solidity ^0.7.0;
import "../math/LogExpMath.sol";
library LogCompression {
    int256 private constant _LOG_COMPRESSION_FACTOR = 1e14;
    int256 private constant _HALF_LOG_COMPRESSION_FACTOR = 0.5e14;
    function toLowResLog(uint256 value) internal pure returns (int256) {
        int256 ln = LogExpMath.ln(int256(value));
        int256 lnWithError = (ln > 0 ? ln + _HALF_LOG_COMPRESSION_FACTOR : ln - _HALF_LOG_COMPRESSION_FACTOR);
        return lnWithError / _LOG_COMPRESSION_FACTOR;
    }
    function fromLowResLog(int256 value) internal pure returns (uint256) {
        return uint256(LogExpMath.exp(value * _LOG_COMPRESSION_FACTOR));
    }
}