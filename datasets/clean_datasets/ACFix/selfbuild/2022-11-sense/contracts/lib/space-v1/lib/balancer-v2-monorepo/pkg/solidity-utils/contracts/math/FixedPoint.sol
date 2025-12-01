pragma solidity ^0.7.0;
import "./LogExpMath.sol";
import "../helpers/BalancerErrors.sol";
library FixedPoint {
    uint256 internal constant ONE = 1e18; 
    uint256 internal constant MAX_POW_RELATIVE_ERROR = 10000; 
    uint256 internal constant MIN_POW_BASE_FREE_EXPONENT = 0.7e18;
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        _require(c >= a, Errors.ADD_OVERFLOW);
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        _require(b <= a, Errors.SUB_OVERFLOW);
        uint256 c = a - b;
        return c;
    }
    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        _require(a == 0 || product / a == b, Errors.MUL_OVERFLOW);
        return product / ONE;
    }
    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 product = a * b;
        _require(a == 0 || product / a == b, Errors.MUL_OVERFLOW);
        if (product == 0) {
            return 0;
        } else {
            return ((product - 1) / ONE) + 1;
        }
    }
    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        _require(b != 0, Errors.ZERO_DIVISION);
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;
            _require(aInflated / a == ONE, Errors.DIV_INTERNAL); 
            return aInflated / b;
        }
    }
    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        _require(b != 0, Errors.ZERO_DIVISION);
        if (a == 0) {
            return 0;
        } else {
            uint256 aInflated = a * ONE;
            _require(aInflated / a == ONE, Errors.DIV_INTERNAL); 
            return ((aInflated - 1) / b) + 1;
        }
    }
    function powDown(uint256 x, uint256 y) internal pure returns (uint256) {
        uint256 raw = LogExpMath.pow(x, y);
        uint256 maxError = add(mulUp(raw, MAX_POW_RELATIVE_ERROR), 1);
        if (raw < maxError) {
            return 0;
        } else {
            return sub(raw, maxError);
        }
    }
    function powUp(uint256 x, uint256 y) internal pure returns (uint256) {
        uint256 raw = LogExpMath.pow(x, y);
        uint256 maxError = add(mulUp(raw, MAX_POW_RELATIVE_ERROR), 1);
        return add(raw, maxError);
    }
    function complement(uint256 x) internal pure returns (uint256) {
        return (x < ONE) ? (ONE - x) : 0;
    }
}