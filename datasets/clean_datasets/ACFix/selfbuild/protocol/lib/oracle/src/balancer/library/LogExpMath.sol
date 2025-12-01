pragma solidity ^0.8.17;
import "./BalancerErrors.sol";
library LogExpMath {
    int256 constant ONE_18 = 1e18;
    int256 constant ONE_20 = 1e20;
    int256 constant ONE_36 = 1e36;
    int256 constant MAX_NATURAL_EXPONENT = 130e18;
    int256 constant MIN_NATURAL_EXPONENT = -41e18;
    int256 constant LN_36_LOWER_BOUND = ONE_18 - 1e17;
    int256 constant LN_36_UPPER_BOUND = ONE_18 + 1e17;
    uint256 constant MILD_EXPONENT_BOUND = 2**254 / uint256(ONE_20);
    int256 constant x0 = 128000000000000000000; 
    int256 constant a0 = 38877084059945950922200000000000000000000000000000000000; 
    int256 constant x1 = 64000000000000000000; 
    int256 constant a1 = 6235149080811616882910000000; 
    int256 constant x2 = 3200000000000000000000; 
    int256 constant a2 = 7896296018268069516100000000000000; 
    int256 constant x3 = 1600000000000000000000; 
    int256 constant a3 = 888611052050787263676000000; 
    int256 constant x4 = 800000000000000000000; 
    int256 constant a4 = 298095798704172827474000; 
    int256 constant x5 = 400000000000000000000; 
    int256 constant a5 = 5459815003314423907810; 
    int256 constant x6 = 200000000000000000000; 
    int256 constant a6 = 738905609893065022723; 
    int256 constant x7 = 100000000000000000000; 
    int256 constant a7 = 271828182845904523536; 
    int256 constant x8 = 50000000000000000000; 
    int256 constant a8 = 164872127070012814685; 
    int256 constant x9 = 25000000000000000000; 
    int256 constant a9 = 128402541668774148407; 
    int256 constant x10 = 12500000000000000000; 
    int256 constant a10 = 113314845306682631683; 
    int256 constant x11 = 6250000000000000000; 
    int256 constant a11 = 106449445891785942956; 
    function pow(uint256 x, uint256 y) internal pure returns (uint256) {
        if (y == 0) {
            return uint256(ONE_18);
        }
        if (x == 0) {
            return 0;
        }
        _require(x >> 255 == 0, Errors.X_OUT_OF_BOUNDS);
        int256 x_int256 = int256(x);
        _require(y < MILD_EXPONENT_BOUND, Errors.Y_OUT_OF_BOUNDS);
        int256 y_int256 = int256(y);
        int256 logx_times_y;
        if (LN_36_LOWER_BOUND < x_int256 && x_int256 < LN_36_UPPER_BOUND) {
            int256 ln_36_x = _ln_36(x_int256);
            logx_times_y = ((ln_36_x / ONE_18) * y_int256 + ((ln_36_x % ONE_18) * y_int256) / ONE_18);
        } else {
            logx_times_y = _ln(x_int256) * y_int256;
        }
        logx_times_y /= ONE_18;
        _require(
            MIN_NATURAL_EXPONENT <= logx_times_y && logx_times_y <= MAX_NATURAL_EXPONENT,
            Errors.PRODUCT_OUT_OF_BOUNDS
        );
        return uint256(exp(logx_times_y));
    }
    function exp(int256 x) internal pure returns (int256) {
        _require(x >= MIN_NATURAL_EXPONENT && x <= MAX_NATURAL_EXPONENT, Errors.INVALID_EXPONENT);
        if (x < 0) {
            return ((ONE_18 * ONE_18) / exp(-x));
        }
        int256 firstAN;
        if (x >= x0) {
            x -= x0;
            firstAN = a0;
        } else if (x >= x1) {
            x -= x1;
            firstAN = a1;
        } else {
            firstAN = 1; 
        }
        x *= 100;
        int256 product = ONE_20;
        if (x >= x2) {
            x -= x2;
            product = (product * a2) / ONE_20;
        }
        if (x >= x3) {
            x -= x3;
            product = (product * a3) / ONE_20;
        }
        if (x >= x4) {
            x -= x4;
            product = (product * a4) / ONE_20;
        }
        if (x >= x5) {
            x -= x5;
            product = (product * a5) / ONE_20;
        }
        if (x >= x6) {
            x -= x6;
            product = (product * a6) / ONE_20;
        }
        if (x >= x7) {
            x -= x7;
            product = (product * a7) / ONE_20;
        }
        if (x >= x8) {
            x -= x8;
            product = (product * a8) / ONE_20;
        }
        if (x >= x9) {
            x -= x9;
            product = (product * a9) / ONE_20;
        }
        int256 seriesSum = ONE_20; 
        int256 term; 
        term = x;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 2;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 3;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 4;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 5;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 6;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 7;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 8;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 9;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 10;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 11;
        seriesSum += term;
        term = ((term * x) / ONE_20) / 12;
        seriesSum += term;
        return (((product * seriesSum) / ONE_20) * firstAN) / 100;
    }
    function log(int256 arg, int256 base) internal pure returns (int256) {
        int256 logBase;
        if (LN_36_LOWER_BOUND < base && base < LN_36_UPPER_BOUND) {
            logBase = _ln_36(base);
        } else {
            logBase = _ln(base) * ONE_18;
        }
        int256 logArg;
        if (LN_36_LOWER_BOUND < arg && arg < LN_36_UPPER_BOUND) {
            logArg = _ln_36(arg);
        } else {
            logArg = _ln(arg) * ONE_18;
        }
        return (logArg * ONE_18) / logBase;
    }
    function ln(int256 a) internal pure returns (int256) {
        _require(a > 0, Errors.OUT_OF_BOUNDS);
        if (LN_36_LOWER_BOUND < a && a < LN_36_UPPER_BOUND) {
            return _ln_36(a) / ONE_18;
        } else {
            return _ln(a);
        }
    }
    function _ln(int256 a) private pure returns (int256) {
        if (a < ONE_18) {
            return (-_ln((ONE_18 * ONE_18) / a));
        }
        int256 sum = 0;
        if (a >= a0 * ONE_18) {
            a /= a0; 
            sum += x0;
        }
        if (a >= a1 * ONE_18) {
            a /= a1; 
            sum += x1;
        }
        sum *= 100;
        a *= 100;
        if (a >= a2) {
            a = (a * ONE_20) / a2;
            sum += x2;
        }
        if (a >= a3) {
            a = (a * ONE_20) / a3;
            sum += x3;
        }
        if (a >= a4) {
            a = (a * ONE_20) / a4;
            sum += x4;
        }
        if (a >= a5) {
            a = (a * ONE_20) / a5;
            sum += x5;
        }
        if (a >= a6) {
            a = (a * ONE_20) / a6;
            sum += x6;
        }
        if (a >= a7) {
            a = (a * ONE_20) / a7;
            sum += x7;
        }
        if (a >= a8) {
            a = (a * ONE_20) / a8;
            sum += x8;
        }
        if (a >= a9) {
            a = (a * ONE_20) / a9;
            sum += x9;
        }
        if (a >= a10) {
            a = (a * ONE_20) / a10;
            sum += x10;
        }
        if (a >= a11) {
            a = (a * ONE_20) / a11;
            sum += x11;
        }
        int256 z = ((a - ONE_20) * ONE_20) / (a + ONE_20);
        int256 z_squared = (z * z) / ONE_20;
        int256 num = z;
        int256 seriesSum = num;
        num = (num * z_squared) / ONE_20;
        seriesSum += num / 3;
        num = (num * z_squared) / ONE_20;
        seriesSum += num / 5;
        num = (num * z_squared) / ONE_20;
        seriesSum += num / 7;
        num = (num * z_squared) / ONE_20;
        seriesSum += num / 9;
        num = (num * z_squared) / ONE_20;
        seriesSum += num / 11;
        seriesSum *= 2;
        return (sum + seriesSum) / 100;
    }
    function _ln_36(int256 x) private pure returns (int256) {
        x *= ONE_18;
        int256 z = ((x - ONE_36) * ONE_36) / (x + ONE_36);
        int256 z_squared = (z * z) / ONE_36;
        int256 num = z;
        int256 seriesSum = num;
        num = (num * z_squared) / ONE_36;
        seriesSum += num / 3;
        num = (num * z_squared) / ONE_36;
        seriesSum += num / 5;
        num = (num * z_squared) / ONE_36;
        seriesSum += num / 7;
        num = (num * z_squared) / ONE_36;
        seriesSum += num / 9;
        num = (num * z_squared) / ONE_36;
        seriesSum += num / 11;
        num = (num * z_squared) / ONE_36;
        seriesSum += num / 13;
        num = (num * z_squared) / ONE_36;
        seriesSum += num / 15;
        return seriesSum * 2;
    }
}