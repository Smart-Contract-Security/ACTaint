pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
library SafeCast {
    function toInt256(uint256 value) internal pure returns (int256) {
        _require(value < 2**255, Errors.SAFE_CAST_VALUE_CANT_FIT_INT256);
        return int256(value);
    }
}