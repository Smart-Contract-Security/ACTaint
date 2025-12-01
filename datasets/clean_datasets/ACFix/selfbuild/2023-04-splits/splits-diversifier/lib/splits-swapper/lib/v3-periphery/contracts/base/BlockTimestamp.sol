pragma solidity =0.8.15;
abstract contract BlockTimestamp {
    function _blockTimestamp() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}