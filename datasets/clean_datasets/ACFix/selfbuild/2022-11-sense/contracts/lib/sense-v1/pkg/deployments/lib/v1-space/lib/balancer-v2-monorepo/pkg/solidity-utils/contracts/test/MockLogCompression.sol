pragma solidity ^0.7.0;
import "../helpers/LogCompression.sol";
contract MockLogCompression {
    function toLowResLog(uint256 value) external pure returns (int256) {
        return LogCompression.toLowResLog(value);
    }
    function fromLowResLog(int256 value) external pure returns (uint256) {
        return LogCompression.fromLowResLog(value);
    }
}