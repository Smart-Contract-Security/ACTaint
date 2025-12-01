pragma solidity 0.8.9;
library DecimalMath {
    uint256 constant ONE = 1e18;
    function decimalMul(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * b) / ONE;
    }
    function decimalDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * ONE) / b;
    }
    function decimalRemainder(uint256 a, uint256 b) internal pure returns (bool) {
        if ((a * ONE) % b == 0) {
            return true;
        } else {
            return false;
        }
    }
}