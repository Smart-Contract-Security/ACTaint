pragma solidity ^0.8.4;
library LibBit {
    function fls(uint256 x) internal pure returns (uint256 r) {
        assembly {
            r := shl(8, iszero(x))
            r := or(r, shl(7, lt(0xffffffffffffffffffffffffffffffff, x)))
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
    function clz(uint256 x) internal pure returns (uint256 r) {
        assembly {
            let t := add(iszero(x), 255)
            r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            x := shr(r, x)
            x := or(x, shr(1, x))
            x := or(x, shr(2, x))
            x := or(x, shr(4, x))
            x := or(x, shr(8, x))
            x := or(x, shr(16, x))
            r := sub(t, or(r, byte(shr(251, mul(x, shl(224, 0x07c4acdd))),
                0x0009010a0d15021d0b0e10121619031e080c141c0f111807131b17061a05041f)))
        }
    }
    function ffs(uint256 x) internal pure returns (uint256 r) {
        assembly {
            r := shl(8, iszero(x))
            x := and(x, add(not(x), 1))
            r := or(r, shl(7, lt(0xffffffffffffffffffffffffffffffff, x)))
            r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
            r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
            r := or(r, byte(shr(251, mul(shr(r, x), shl(224, 0x077cb531))), 
                0x00011c021d0e18031e16140f191104081f1b0d17151310071a0c12060b050a09))
        }
    }
    function popCount(uint256 x) internal pure returns (uint256 c) {
        assembly {
            let max := not(0)
            let isMax := eq(x, max)
            x := sub(x, and(shr(1, x), div(max, 3)))
            x := add(and(x, div(max, 5)), and(shr(2, x), div(max, 5)))
            x := and(add(x, shr(4, x)), div(max, 17))
            c := or(shl(8, isMax), shr(248, mul(x, div(max, 255))))
        }
    }
    function isPo2(uint256 x) internal pure returns (bool result) {
        assembly {
            result := iszero(add(and(x, sub(x, 1)), iszero(x)))
        }
    }
    function and(bool x, bool y) internal pure returns (bool z) {
        assembly {
            z := and(x, y)
        }
    }
    function or(bool x, bool y) internal pure returns (bool z) {
        assembly {
            z := or(x, y)
        }
    }
    function toUint(bool b) internal pure returns (uint256 z) {
        assembly {
            z := b
        }
    }
}