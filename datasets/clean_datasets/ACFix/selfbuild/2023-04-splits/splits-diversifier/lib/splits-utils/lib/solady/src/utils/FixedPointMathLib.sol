pragma solidity ^0.8.4;
library FixedPointMathLib {
    error ExpOverflow();
    error FactorialOverflow();
    error MulWadFailed();
    error DivWadFailed();
    error MulDivFailed();
    error DivFailed();
    error FullMulDivFailed();
    error LnWadUndefined();
    error Log2Undefined();
    uint256 internal constant WAD = 1e18;
    function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            if mul(y, gt(x, div(not(0), y))) {
                mstore(0x00, 0xbac65e5b)
                revert(0x1c, 0x04)
            }
            z := div(mul(x, y), WAD)
        }
    }
    function mulWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            if mul(y, gt(x, div(not(0), y))) {
                mstore(0x00, 0xbac65e5b)
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(mul(x, y), WAD))), div(mul(x, y), WAD))
        }
    }
    function divWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(y, iszero(mul(WAD, gt(x, div(not(0), WAD)))))) {
                mstore(0x00, 0x7c5f487d)
                revert(0x1c, 0x04)
            }
            z := div(mul(x, WAD), y)
        }
    }
    function divWadUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(y, iszero(mul(WAD, gt(x, div(not(0), WAD)))))) {
                mstore(0x00, 0x7c5f487d)
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(mul(x, WAD), y))), div(mul(x, WAD), y))
        }
    }
    function powWad(int256 x, int256 y) internal pure returns (int256) {
        return expWad((lnWad(x) * y) / int256(WAD));
    }
    function expWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            if (x <= -42139678854452767551) return r;
            assembly {
                if iszero(slt(x, 135305999368893231589)) {
                    mstore(0x00, 0xa37bfec9)
                    revert(0x1c, 0x04)
                }
            }
            x = (x << 78) / 5 ** 18;
            int256 k = ((x << 96) / 54916777467707473351141471128 + 2 ** 95) >> 96;
            x = x - k * 54916777467707473351141471128;
            int256 y = x + 1346386616545796478920950773328;
            y = ((y * x) >> 96) + 57155421227552351082224309758442;
            int256 p = y + x - 94201549194550492254356042504812;
            p = ((p * y) >> 96) + 28719021644029726153956944680412240;
            p = p * x + (4385272521454847904659076985693276 << 96);
            int256 q = x - 2855989394907223263936484059900;
            q = ((q * x) >> 96) + 50020603652535783019961831881945;
            q = ((q * x) >> 96) - 533845033583426703283633433725380;
            q = ((q * x) >> 96) + 3604857256930695427073651918091429;
            q = ((q * x) >> 96) - 14423608567350463180887372962807573;
            q = ((q * x) >> 96) + 26449188498355588339934803723976023;
            assembly {
                r := sdiv(p, q)
            }
            r = int256(
                (uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k)
            );
        }
    }
    function lnWad(int256 x) internal pure returns (int256 r) {
        unchecked {
            assembly {
                if iszero(sgt(x, 0)) {
                    mstore(0x00, 0x1615e638)
                    revert(0x1c, 0x04)
                }
            }
            int256 k;
            assembly {
                let v := x
                k := shl(7, lt(0xffffffffffffffffffffffffffffffff, v))
                k := or(k, shl(6, lt(0xffffffffffffffff, shr(k, v))))
                k := or(k, shl(5, lt(0xffffffff, shr(k, v))))
                v := shr(k, v)
                v := or(v, shr(1, v))
                v := or(v, shr(2, v))
                v := or(v, shr(4, v))
                v := or(v, shr(8, v))
                v := or(v, shr(16, v))
                k := sub(or(k, byte(shr(251, mul(v, shl(224, 0x07c4acdd))),
                    0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f)), 96)
            }
            x <<= uint256(159 - k);
            x = int256(uint256(x) >> 159);
            int256 p = x + 3273285459638523848632254066296;
            p = ((p * x) >> 96) + 24828157081833163892658089445524;
            p = ((p * x) >> 96) + 43456485725739037958740375743393;
            p = ((p * x) >> 96) - 11111509109440967052023855526967;
            p = ((p * x) >> 96) - 45023709667254063763336534515857;
            p = ((p * x) >> 96) - 14706773417378608786704636184526;
            p = p * x - (795164235651350426258249787498 << 96);
            int256 q = x + 5573035233440673466300451813936;
            q = ((q * x) >> 96) + 71694874799317883764090561454958;
            q = ((q * x) >> 96) + 283447036172924575727196451306956;
            q = ((q * x) >> 96) + 401686690394027663651624208769553;
            q = ((q * x) >> 96) + 204048457590392012362485061816622;
            q = ((q * x) >> 96) + 31853899698501571402653359427138;
            q = ((q * x) >> 96) + 909429971244387300277376558375;
            assembly {
                r := sdiv(p, q)
            }
            r *= 1677202110996718588342820967067443963516166;
            r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
            r += 600920179829731861736702779321621459595472258049074101567377883020018308;
            r >>= 174;
        }
    }
    function fullMulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 result) {
        assembly {
            for {} 1 {} {
                let prod0 := mul(x, y)
                let mm := mulmod(x, y, not(0))
                let prod1 := sub(mm, add(prod0, lt(mm, prod0)))
                if iszero(prod1) {
                    if iszero(d) {
                        mstore(0x00, 0xae47f702)
                        revert(0x1c, 0x04)
                    }
                    result := div(prod0, d)
                    break       
                }
                if iszero(gt(d, prod1)) {
                    mstore(0x00, 0xae47f702)
                    revert(0x1c, 0x04)
                }
                let remainder := mulmod(x, y, d)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
                let twos := and(d, sub(0, d))
                d := div(d, twos)
                prod0 := div(prod0, twos)
                prod0 := or(prod0, mul(prod1, add(div(sub(0, twos), twos), 1)))
                let inv := xor(mul(3, d), 2)
                inv := mul(inv, sub(2, mul(d, inv))) 
                inv := mul(inv, sub(2, mul(d, inv))) 
                inv := mul(inv, sub(2, mul(d, inv))) 
                inv := mul(inv, sub(2, mul(d, inv))) 
                inv := mul(inv, sub(2, mul(d, inv))) 
                result := mul(prod0, mul(inv, sub(2, mul(d, inv)))) 
                break
            }
        }
    }
    function fullMulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 result) {
        result = fullMulDiv(x, y, d);
        assembly {
            if mulmod(x, y, d) {
                if iszero(add(result, 1)) {
                    mstore(0x00, 0xae47f702)
                    revert(0x1c, 0x04)
                }
                result := add(result, 1)
            }
        }
    }
    function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(d, iszero(mul(y, gt(x, div(not(0), y)))))) {
                mstore(0x00, 0xad251c27)
                revert(0x1c, 0x04)
            }
            z := div(mul(x, y), d)
        }
    }
    function mulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        assembly {
            if iszero(mul(d, iszero(mul(y, gt(x, div(not(0), y)))))) {
                mstore(0x00, 0xad251c27)
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(mul(x, y), d))), div(mul(x, y), d))
        }
    }
    function divUp(uint256 x, uint256 d) internal pure returns (uint256 z) {
        assembly {
            if iszero(d) {
                mstore(0x00, 0x65244e4e)
                revert(0x1c, 0x04)
            }
            z := add(iszero(iszero(mod(x, d))), div(x, d))
        }
    }
    function zeroFloorSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := mul(gt(x, y), sub(x, y))
        }
    }
    function sqrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            z := 181 
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffffff, shr(r, x))))
            z := shl(shr(1, r), z)
            z := shr(18, mul(z, add(shr(r, x), 65536))) 
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
    function cbrt(uint256 x) internal pure returns (uint256 z) {
        assembly {
            let r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            z := shl(add(div(r, 3), lt(0xf, shr(r, x))), 0xff)
            z := div(z, byte(mod(r, 3), shl(232, 0x7f624b)))
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := div(add(add(div(x, mul(z, z)), z), z), 3)
            z := sub(z, lt(div(x, mul(z, z)), z))
        }
    }
    function factorial(uint256 x) internal pure returns (uint256 result) {
        assembly {
            for {} 1 {} {
                if iszero(lt(10, x)) {
                    result := and(
                        shr(mul(22, x), 0x375f0016260009d80004ec0002d00001e0000180000180000200000400001),
                        0x3fffff
                    )
                    break
                }
                if iszero(lt(57, x)) {
                    let end := 31
                    result := 8222838654177922817725562880000000
                    if iszero(lt(end, x)) {
                        end := 10
                        result := 3628800
                    }
                    for { let w := not(0) } 1 {} {
                        result := mul(result, x)
                        x := add(x, w)
                        if eq(x, end) { break }
                    }
                    break
                }
                mstore(0x00, 0xaba0f2a2)
                revert(0x1c, 0x04)
            }
        }
    }
    function log2(uint256 x) internal pure returns (uint256 r) {
        assembly {
            if iszero(x) {
                mstore(0x00, 0x5be3aa5c)
                revert(0x1c, 0x04)
            }
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            x := shr(r, x)
            x := or(x, shr(1, x))
            x := or(x, shr(2, x))
            x := or(x, shr(4, x))
            x := or(x, shr(8, x))
            x := or(x, shr(16, x))
            r := or(r, byte(shr(251, mul(x, shl(224, 0x07c4acdd))),
                0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f))
        }
    }
    function log2Up(uint256 x) internal pure returns (uint256 r) {
        unchecked {
            uint256 isNotPo2;
            assembly {
                isNotPo2 := iszero(iszero(and(x, sub(x, 1))))
            }
            return log2(x) + isNotPo2;
        }
    }
    function avg(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = (x & y) + ((x ^ y) >> 1);
        }
    }
    function avg(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = (x >> 1) + (y >> 1) + (((x & 1) + (y & 1)) >> 1);
        }
    }
    function abs(int256 x) internal pure returns (uint256 z) {
        assembly {
            let mask := sub(0, shr(255, x))
            z := xor(mask, add(mask, x))
        }
    }
    function dist(int256 x, int256 y) internal pure returns (uint256 z) {
        assembly {
            let a := sub(y, x)
            z := xor(a, mul(xor(a, sub(x, y)), sgt(x, y)))
        }
    }
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }
    function min(int256 x, int256 y) internal pure returns (int256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), slt(y, x)))
        }
    }
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }
    function max(int256 x, int256 y) internal pure returns (int256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), sgt(y, x)))
        }
    }
    function clamp(uint256 x, uint256 minValue, uint256 maxValue)
        internal
        pure
        returns (uint256 z)
    {
        z = min(max(x, minValue), maxValue);
    }
    function clamp(int256 x, int256 minValue, int256 maxValue) internal pure returns (int256 z) {
        z = min(max(x, minValue), maxValue);
    }
    function gcd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            for { z := x } y {} {
                let t := y
                y := mod(z, y)
                z := t
            }
        }
    }
    function rawAdd(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x + y;
        }
    }
    function rawAdd(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x + y;
        }
    }
    function rawSub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x - y;
        }
    }
    function rawSub(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x - y;
        }
    }
    function rawMul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x * y;
        }
    }
    function rawMul(int256 x, int256 y) internal pure returns (int256 z) {
        unchecked {
            z = x * y;
        }
    }
    function rawDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := div(x, y)
        }
    }
    function rawSDiv(int256 x, int256 y) internal pure returns (int256 z) {
        assembly {
            z := sdiv(x, y)
        }
    }
    function rawMod(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := mod(x, y)
        }
    }
    function rawSMod(int256 x, int256 y) internal pure returns (int256 z) {
        assembly {
            z := smod(x, y)
        }
    }
    function rawAddMod(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        assembly {
            z := addmod(x, y, d)
        }
    }
    function rawMulMod(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 z) {
        assembly {
            z := mulmod(x, y, d)
        }
    }
}