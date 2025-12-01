pragma solidity ^0.7.0;
import "@balancer-labs/v2-solidity-utils/contracts/math/FixedPoint.sol";
library WeightCompression {
    uint256 private constant _UINT31_MAX = 2**(31) - 1;
    using FixedPoint for uint256;
    function uncompress16(uint256 value) internal pure returns (uint256) {
        return value.mulUp(FixedPoint.ONE).divUp(type(uint16).max);
    }
    function compress16(uint256 value) internal pure returns (uint256) {
        return value.mulUp(type(uint16).max).divUp(FixedPoint.ONE);
    }
    function uncompress31(uint256 value) internal pure returns (uint256) {
        return value.mulUp(FixedPoint.ONE).divUp(_UINT31_MAX);
    }
    function compress31(uint256 value) internal pure returns (uint256) {
        return value.mulUp(_UINT31_MAX).divUp(FixedPoint.ONE);
    }
    function uncompress32(uint256 value) internal pure returns (uint256) {
        return value.mulUp(FixedPoint.ONE).divUp(type(uint32).max);
    }
    function compress32(uint256 value) internal pure returns (uint256) {
        return value.mulUp(type(uint32).max).divUp(FixedPoint.ONE);
    }
    function uncompress64(uint256 value) internal pure returns (uint256) {
        return value.mulUp(FixedPoint.ONE).divUp(type(uint64).max);
    }
    function compress64(uint256 value) internal pure returns (uint256) {
        return value.mulUp(type(uint64).max).divUp(FixedPoint.ONE);
    }
}