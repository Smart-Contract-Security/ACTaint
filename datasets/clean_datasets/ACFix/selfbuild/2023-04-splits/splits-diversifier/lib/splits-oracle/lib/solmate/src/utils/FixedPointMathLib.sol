pragma solidity >=0.8.0;
library FixedPointMathLib {
    uint256 internal constant MAX_UINT256 = 2**256 - 1;
    uint256 internal constant WAD = 1e18; 
    function mulWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, y, WAD); 
    }
    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, y, WAD); 
    }
    function divWadDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivDown(x, WAD, y); 
    }
    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256) {
        return mulDivUp(x, WAD, y); 
    }
    function mulDivDown(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }
            z := div(mul(x, y), denominator)
        }
    }
    function mulDivUp(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(denominator, iszero(mul(y, gt(x, div(MAX_UINT256, y)))))) {
                revert(0, 0)
            }
            z := add(gt(mod(mul(x, y), denominator), 0), div(mul(x, y), denominator))
        }
    }
    function rpow(
        uint256 x,
        uint256 n,
        uint256 scalar
    ) internal pure returns (uint256 z) {
        assembly {
            switch x
            case 0 {
                switch n
                case 0 {
                    z := scalar
                }
                default {
                    z := 0
                }
            }
            default {
                switch mod(n, 2)
                case 0 {
                    z := scalar
                }
                default {
                    z := x
                }
                let half := shr(1, scalar)
                for {
                    n := shr(1, n)
                } n {
                    n := shr(1, n)
                } {
                    if shr(128, x) {
                        revert(0, 0)
                    }
                    let xx := mul(x, x)
                    let xxRound := add(xx, half)
                    if lt(xxRound, xx) {
                        revert(0, 0)
                    }
                    x := div(xxRound, scalar)
                    if mod(n, 2) {
                        let zx := mul(z, x)
                        if iszero(eq(div(zx, x), z)) {
                            if iszero(iszero(x)) {
                                revert(0, 0)
                            }
                        }
                        let zxRound := add(zx, half)
                        if lt(zxRound, zx) {
                            revert(0, 0)
                        }
                        z := div(zxRound, scalar)
                    }
                }
            }
        }
    }
    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            let y := x 
            z := 181 
            if iszero(lt(y, 0x10000000000000000000000000000000000)) {
                y := shr(128, y)
                z := shl(64, z)
            }
            if iszero(lt(y, 0x1000000000000000000)) {
                y := shr(64, y)
                z := shl(32, z)
            }
            if iszero(lt(y, 0x10000000000)) {
                y := shr(32, y)
                z := shl(16, z)
            }
            if iszero(lt(y, 0x1000000)) {
                y := shr(16, y)
                z := shl(8, z)
            }
            z := shr(18, mul(z, add(y, 65536))) 
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := shr(1, add(z, div(x, z)))
            z := sub(z, lt(div(x, z), z))
        }
    }
    function unsafeMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := mod(x, y)
        }
    }
    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 r) {
        assembly {
            r := div(x, y)
        }
    }
    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }
}