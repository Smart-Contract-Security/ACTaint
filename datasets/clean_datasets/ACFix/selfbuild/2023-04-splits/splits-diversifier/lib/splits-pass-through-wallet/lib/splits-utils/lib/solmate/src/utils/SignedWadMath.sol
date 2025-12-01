pragma solidity >=0.8.0;
function toWadUnsafe(uint256 x) pure returns (int256 r) {
    assembly {
        r := mul(x, 1000000000000000000)
    }
}
function toDaysWadUnsafe(uint256 x) pure returns (int256 r) {
    assembly {
        r := div(mul(x, 1000000000000000000), 86400)
    }
}
function fromDaysWadUnsafe(int256 x) pure returns (uint256 r) {
    assembly {
        r := div(mul(x, 86400), 1000000000000000000)
    }
}
function unsafeWadMul(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := sdiv(mul(x, y), 1000000000000000000)
    }
}
function unsafeWadDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := sdiv(mul(x, 1000000000000000000), y)
    }
}
function wadMul(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := mul(x, y)
        if iszero(or(iszero(x), eq(sdiv(r, x), y))) {
            revert(0, 0)
        }
        r := sdiv(r, 1000000000000000000)
    }
}
function wadDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := mul(x, 1000000000000000000)
        if iszero(and(iszero(iszero(y)), eq(sdiv(r, 1000000000000000000), x))) {
            revert(0, 0)
        }
        r := sdiv(r, y)
    }
}
function wadPow(int256 x, int256 y) pure returns (int256) {
    return wadExp((wadLn(x) * y) / 1e18); 
}
function wadExp(int256 x) pure returns (int256 r) {
    unchecked {
        if (x <= -42139678854452767551) return 0;
        if (x >= 135305999368893231589) revert("EXP_OVERFLOW");
        x = (x << 78) / 5**18;
        int256 k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
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
        r = int256((uint256(r) * 3822833074963236453042738258902158003155416615667) >> uint256(195 - k));
    }
}
function wadLn(int256 x) pure returns (int256 r) {
    unchecked {
        require(x > 0, "UNDEFINED");
        assembly {
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, shl(4, lt(0xffff, shr(r, x))))
            r := or(r, shl(3, lt(0xff, shr(r, x))))
            r := or(r, shl(2, lt(0xf, shr(r, x))))
            r := or(r, shl(1, lt(0x3, shr(r, x))))
            r := or(r, lt(0x1, shr(r, x)))
        }
        int256 k = r - 96;
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
function unsafeDiv(int256 x, int256 y) pure returns (int256 r) {
    assembly {
        r := sdiv(x, y)
    }
}