pragma solidity 0.8.11;
library FixedMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;
    function fmul(
        uint256 x,
        uint256 y,
        uint256 baseUnit
    ) internal pure returns (uint256) {
        return mulDivDown(x, y, baseUnit); 
    }
    function fmul(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); 
    }
    function fmulUp(
        uint256 x,
        uint256 y,
        uint256 baseUnit
    ) internal pure returns (uint256) {
        return mulDivUp(x, y, baseUnit); 
    }
    function fmulUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); 
    }
    function fdiv(
        uint256 x,
        uint256 y,
        uint256 baseUnit
    ) internal pure returns (uint256) {
        return mulDivDown(x, baseUnit, y); 
    }
    function fdiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); 
    }
    function fdivUp(
        uint256 x,
        uint256 y,
        uint256 baseUnit
    ) internal pure returns (uint256) {
        return mulDivUp(x, baseUnit, y); 
    }
    function fdivUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); 
    }
    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            z := mul(x, y)
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }
            z := div(z, denominator)
        }
    }
    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            z := mul(x, y)
            if iszero(and(iszero(iszero(denominator)), or(iszero(x), eq(div(z, x), y)))) {
                revert(0, 0)
            }
            z := mul(iszero(iszero(z)), add(div(sub(z, 1), denominator), 1))
        }
    }
}