pragma solidity ^0.7.0;
library WordCodec {
    uint256 private constant _MASK_1 = 2**(1) - 1;
    uint256 private constant _MASK_5 = 2**(5) - 1;
    uint256 private constant _MASK_7 = 2**(7) - 1;
    uint256 private constant _MASK_10 = 2**(10) - 1;
    uint256 private constant _MASK_16 = 2**(16) - 1;
    uint256 private constant _MASK_22 = 2**(22) - 1;
    uint256 private constant _MASK_31 = 2**(31) - 1;
    uint256 private constant _MASK_32 = 2**(32) - 1;
    uint256 private constant _MASK_53 = 2**(53) - 1;
    uint256 private constant _MASK_64 = 2**(64) - 1;
    uint256 private constant _MASK_128 = 2**(128) - 1;
    uint256 private constant _MASK_192 = 2**(192) - 1;
    int256 private constant _MAX_INT_22 = 2**(21) - 1;
    int256 private constant _MAX_INT_53 = 2**(52) - 1;
    function insertBool(
        bytes32 word,
        bool value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_1 << offset));
        return clearedWord | bytes32(uint256(value ? 1 : 0) << offset);
    }
    function insertUint5(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_5 << offset));
        return clearedWord | bytes32(value << offset);
    }
    function insertUint7(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_7 << offset));
        return clearedWord | bytes32(value << offset);
    }
    function insertUint10(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_10 << offset));
        return clearedWord | bytes32(value << offset);
    }
    function insertUint16(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_16 << offset));
        return clearedWord | bytes32(value << offset);
    }
    function insertUint31(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_31 << offset));
        return clearedWord | bytes32(value << offset);
    }
    function insertUint32(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_32 << offset));
        return clearedWord | bytes32(value << offset);
    }
    function insertUint64(
        bytes32 word,
        uint256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_64 << offset));
        return clearedWord | bytes32(value << offset);
    }
    function insertInt22(
        bytes32 word,
        int256 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_22 << offset));
        return clearedWord | bytes32((uint256(value) & _MASK_22) << offset);
    }
    function insertBits192(
        bytes32 word,
        bytes32 value,
        uint256 offset
    ) internal pure returns (bytes32) {
        bytes32 clearedWord = bytes32(uint256(word) & ~(_MASK_192 << offset));
        return clearedWord | bytes32((uint256(value) & _MASK_192) << offset);
    }
    function encodeUint(uint256 value, uint256 offset) internal pure returns (bytes32) {
        return bytes32(value << offset);
    }
    function encodeInt22(int256 value, uint256 offset) internal pure returns (bytes32) {
        return bytes32((uint256(value) & _MASK_22) << offset);
    }
    function encodeInt53(int256 value, uint256 offset) internal pure returns (bytes32) {
        return bytes32((uint256(value) & _MASK_53) << offset);
    }
    function decodeBool(bytes32 word, uint256 offset) internal pure returns (bool) {
        return (uint256(word >> offset) & _MASK_1) == 1;
    }
    function decodeUint5(bytes32 word, uint256 offset) internal pure returns (uint256) {
        return uint256(word >> offset) & _MASK_5;
    }
    function decodeUint7(bytes32 word, uint256 offset) internal pure returns (uint256) {
        return uint256(word >> offset) & _MASK_7;
    }
    function decodeUint10(bytes32 word, uint256 offset) internal pure returns (uint256) {
        return uint256(word >> offset) & _MASK_10;
    }
    function decodeUint16(bytes32 word, uint256 offset) internal pure returns (uint256) {
        return uint256(word >> offset) & _MASK_16;
    }
    function decodeUint31(bytes32 word, uint256 offset) internal pure returns (uint256) {
        return uint256(word >> offset) & _MASK_31;
    }
    function decodeUint32(bytes32 word, uint256 offset) internal pure returns (uint256) {
        return uint256(word >> offset) & _MASK_32;
    }
    function decodeUint64(bytes32 word, uint256 offset) internal pure returns (uint256) {
        return uint256(word >> offset) & _MASK_64;
    }
    function decodeUint128(bytes32 word, uint256 offset) internal pure returns (uint256) {
        return uint256(word >> offset) & _MASK_128;
    }
    function decodeInt22(bytes32 word, uint256 offset) internal pure returns (int256) {
        int256 value = int256(uint256(word >> offset) & _MASK_22);
        return value > _MAX_INT_22 ? (value | int256(~_MASK_22)) : value;
    }
    function decodeInt53(bytes32 word, uint256 offset) internal pure returns (int256) {
        int256 value = int256(uint256(word >> offset) & _MASK_53);
        return value > _MAX_INT_53 ? (value | int256(~_MASK_53)) : value;
    }
}