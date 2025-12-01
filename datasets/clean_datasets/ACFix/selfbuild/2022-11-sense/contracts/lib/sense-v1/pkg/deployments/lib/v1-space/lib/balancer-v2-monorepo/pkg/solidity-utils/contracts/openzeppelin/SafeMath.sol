pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        _require(c >= a, Errors.ADD_OVERFLOW);
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, Errors.SUB_OVERFLOW);
    }
    function sub(uint256 a, uint256 b, uint256 errorCode) internal pure returns (uint256) {
        _require(b <= a, errorCode);
        uint256 c = a - b;
        return c;
    }
}