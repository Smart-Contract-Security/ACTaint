pragma solidity >=0.8.0;
library SafeCastLib {
    function safeCastTo248(uint256 x) internal pure returns (uint248 y) {
        require(x <= type(uint248).max);
        y = uint248(x);
    }
    function safeCastTo224(uint256 x) internal pure returns (uint224 y) {
        require(x <= type(uint224).max);
        y = uint224(x);
    }
    function safeCastTo128(uint256 x) internal pure returns (uint128 y) {
        require(x <= type(uint128).max);
        y = uint128(x);
    }
    function safeCastTo96(uint256 x) internal pure returns (uint96 y) {
        require(x <= type(uint96).max);
        y = uint96(x);
    }
    function safeCastTo64(uint256 x) internal pure returns (uint64 y) {
        require(x <= type(uint64).max);
        y = uint64(x);
    }
    function safeCastTo32(uint256 x) internal pure returns (uint32 y) {
        require(x <= type(uint32).max);
        y = uint32(x);
    }
    function safeCastTo8(uint256 x) internal pure returns (uint8 y) {
        require(x <= type(uint8).max);
        y = uint8(x);
    }
}