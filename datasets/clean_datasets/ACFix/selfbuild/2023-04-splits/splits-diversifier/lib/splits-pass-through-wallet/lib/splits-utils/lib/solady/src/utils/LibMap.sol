pragma solidity ^0.8.4;
library LibMap {
    struct Uint8Map {
        mapping(uint256 => uint256) map;
    }
    struct Uint16Map {
        mapping(uint256 => uint256) map;
    }
    struct Uint32Map {
        mapping(uint256 => uint256) map;
    }
    struct Uint64Map {
        mapping(uint256 => uint256) map;
    }
    struct Uint128Map {
        mapping(uint256 => uint256) map;
    }
    function get(Uint8Map storage map, uint256 index) internal view returns (uint8 result) {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(5, index))
            result := byte(and(31, not(index)), sload(keccak256(0x00, 0x40)))
        }
    }
    function set(Uint8Map storage map, uint256 index, uint8 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(5, index))
            let s := keccak256(0x00, 0x40) 
            mstore(0x00, sload(s))
            mstore8(and(31, not(index)), value)
            sstore(s, mload(0x00))
        }
    }
    function get(Uint16Map storage map, uint256 index) internal view returns (uint16 result) {
        result = uint16(map.map[index >> 4] >> ((index & 15) << 4));
    }
    function set(Uint16Map storage map, uint256 index, uint16 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(4, index))
            let s := keccak256(0x00, 0x40) 
            let o := shl(4, and(index, 15)) 
            let v := sload(s) 
            let m := 0xffff 
            sstore(s, xor(v, shl(o, and(m, xor(shr(o, v), value)))))
        }
    }
    function get(Uint32Map storage map, uint256 index) internal view returns (uint32 result) {
        result = uint32(map.map[index >> 3] >> ((index & 7) << 5));
    }
    function set(Uint32Map storage map, uint256 index, uint32 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(3, index))
            let s := keccak256(0x00, 0x40) 
            let o := shl(5, and(index, 7)) 
            let v := sload(s) 
            let m := 0xffffffff 
            sstore(s, xor(v, shl(o, and(m, xor(shr(o, v), value)))))
        }
    }
    function get(Uint64Map storage map, uint256 index) internal view returns (uint64 result) {
        result = uint64(map.map[index >> 2] >> ((index & 3) << 6));
    }
    function set(Uint64Map storage map, uint256 index, uint64 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(2, index))
            let s := keccak256(0x00, 0x40) 
            let o := shl(6, and(index, 3)) 
            let v := sload(s) 
            let m := 0xffffffffffffffff 
            sstore(s, xor(v, shl(o, and(m, xor(shr(o, v), value)))))
        }
    }
    function get(Uint128Map storage map, uint256 index) internal view returns (uint128 result) {
        result = uint128(map.map[index >> 1] >> ((index & 1) << 7));
    }
    function set(Uint128Map storage map, uint256 index, uint128 value) internal {
        assembly {
            mstore(0x20, map.slot)
            mstore(0x00, shr(1, index))
            let s := keccak256(0x00, 0x40) 
            let o := shl(7, and(index, 1)) 
            let v := sload(s) 
            let m := 0xffffffffffffffffffffffffffffffff 
            sstore(s, xor(v, shl(o, and(m, xor(shr(o, v), value)))))
        }
    }
}