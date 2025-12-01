pragma solidity ^0.8.4;
abstract contract Clone {
    function _getArgBytes(uint256 argOffset, uint256 length)
        internal
        pure
        returns (bytes memory arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := mload(0x40)
            mstore(arg, length)
            calldatacopy(add(arg, 0x20), add(offset, argOffset), length)
            mstore(0x40, and(add(add(arg, 0x3f), length), not(0x1f)))
        }
    }
    function _getArgAddress(uint256 argOffset) internal pure returns (address arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(96, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint256Array(uint256 argOffset, uint256 length)
        internal
        pure
        returns (uint256[] memory arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := mload(0x40)
            mstore(arg, length)
            calldatacopy(add(arg, 0x20), add(offset, argOffset), shl(5, length))
            mstore(0x40, add(add(arg, 0x20), shl(5, length)))
        }
    }
    function _getArgBytes32Array(uint256 argOffset, uint256 length)
        internal
        pure
        returns (bytes32[] memory arg)
    {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := mload(0x40)
            mstore(arg, length)
            calldatacopy(add(arg, 0x20), add(offset, argOffset), shl(5, length))
            mstore(0x40, add(add(arg, 0x20), shl(5, length)))
        }
    }
    function _getArgBytes32(uint256 argOffset) internal pure returns (bytes32 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }
    function _getArgUint256(uint256 argOffset) internal pure returns (uint256 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }
    function _getArgUint248(uint256 argOffset) internal pure returns (uint248 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(8, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint240(uint256 argOffset) internal pure returns (uint240 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(16, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint232(uint256 argOffset) internal pure returns (uint232 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(24, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint224(uint256 argOffset) internal pure returns (uint224 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(32, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint216(uint256 argOffset) internal pure returns (uint216 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(40, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint208(uint256 argOffset) internal pure returns (uint208 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(48, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint200(uint256 argOffset) internal pure returns (uint200 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(56, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint192(uint256 argOffset) internal pure returns (uint192 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(64, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint184(uint256 argOffset) internal pure returns (uint184 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(72, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint176(uint256 argOffset) internal pure returns (uint176 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(80, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint168(uint256 argOffset) internal pure returns (uint168 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(88, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint160(uint256 argOffset) internal pure returns (uint160 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(96, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint152(uint256 argOffset) internal pure returns (uint152 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(104, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint144(uint256 argOffset) internal pure returns (uint144 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(112, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint136(uint256 argOffset) internal pure returns (uint136 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(120, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint128(uint256 argOffset) internal pure returns (uint128 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(128, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint120(uint256 argOffset) internal pure returns (uint120 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(136, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint112(uint256 argOffset) internal pure returns (uint112 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(144, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint104(uint256 argOffset) internal pure returns (uint104 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(152, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint96(uint256 argOffset) internal pure returns (uint96 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(160, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint88(uint256 argOffset) internal pure returns (uint88 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(168, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint80(uint256 argOffset) internal pure returns (uint80 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(176, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint72(uint256 argOffset) internal pure returns (uint72 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(184, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint64(uint256 argOffset) internal pure returns (uint64 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(192, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint56(uint256 argOffset) internal pure returns (uint56 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(200, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint48(uint256 argOffset) internal pure returns (uint48 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(208, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint40(uint256 argOffset) internal pure returns (uint40 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(216, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint32(uint256 argOffset) internal pure returns (uint32 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(224, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint24(uint256 argOffset) internal pure returns (uint24 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(232, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint16(uint256 argOffset) internal pure returns (uint16 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(240, calldataload(add(offset, argOffset)))
        }
    }
    function _getArgUint8(uint256 argOffset) internal pure returns (uint8 arg) {
        uint256 offset = _getImmutableArgsOffset();
        assembly {
            arg := shr(248, calldataload(add(offset, argOffset)))
        }
    }
    function _getImmutableArgsOffset() internal pure returns (uint256 offset) {
        assembly {
            offset := sub(calldatasize(), shr(240, calldataload(sub(calldatasize(), 2))))
        }
    }
}