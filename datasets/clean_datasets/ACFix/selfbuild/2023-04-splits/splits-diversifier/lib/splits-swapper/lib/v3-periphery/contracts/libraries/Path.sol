pragma solidity >=0.6.0;
import './BytesLib.sol';
library Path {
    using BytesLib for bytes;
    uint256 private constant ADDR_SIZE = 20;
    uint256 private constant FEE_SIZE = 3;
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + FEE_SIZE;
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;
    uint256 private constant MULTIPLE_POOLS_MIN_LENGTH = POP_OFFSET + NEXT_OFFSET;
    function hasMultiplePools(bytes memory path) internal pure returns (bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGTH;
    }
    function numPools(bytes memory path) internal pure returns (uint256) {
        return ((path.length - ADDR_SIZE) / NEXT_OFFSET);
    }
    function decodeFirstPool(bytes memory path)
        internal
        pure
        returns (
            address tokenA,
            address tokenB,
            uint24 fee
        )
    {
        tokenA = path.toAddress(0);
        fee = path.toUint24(ADDR_SIZE);
        tokenB = path.toAddress(NEXT_OFFSET);
    }
    function getFirstPool(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(0, POP_OFFSET);
    }
    function skipToken(bytes memory path) internal pure returns (bytes memory) {
        return path.slice(NEXT_OFFSET, path.length - NEXT_OFFSET);
    }
}