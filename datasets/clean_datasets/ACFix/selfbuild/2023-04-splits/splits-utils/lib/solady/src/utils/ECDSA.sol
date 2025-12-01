pragma solidity ^0.8.4;
library ECDSA {
    error InvalidSignature();
    bytes32 private constant _MALLEABILITY_THRESHOLD =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
    function recover(bytes32 hash, bytes memory signature) internal view returns (address result) {
        assembly {
            let m := mload(0x40)
            mstore(0x40, mload(add(signature, 0x20))) 
            let s := mload(add(signature, 0x40))
            mstore(0x60, s)
            mstore(0x00, hash)
            mstore(0x20, byte(0, mload(add(signature, 0x60))))
            pop(
                staticcall(
                    gas(), 
                    and(
                        eq(mload(signature), 65),
                        lt(s, add(_MALLEABILITY_THRESHOLD, 1))
                    ), 
                    0x00, 
                    0x80, 
                    0x00, 
                    0x20 
                )
            )
            result := mload(0x00)
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f)
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }
    function recoverCalldata(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        assembly {
            let m := mload(0x40)
            calldatacopy(0x40, signature.offset, 0x40)
            mstore(0x00, hash)
            mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40))))
            pop(
                staticcall(
                    gas(), 
                    and(
                        eq(signature.length, 65),
                        lt(mload(0x60), add(_MALLEABILITY_THRESHOLD, 1))
                    ), 
                    0x00, 
                    0x80, 
                    0x00, 
                    0x20 
                )
            )
            result := mload(0x00)
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f)
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address result) {
        uint8 v;
        bytes32 s;
        assembly {
            s := shr(1, shl(1, vs))
            v := add(shr(255, vs), 27)
        }
        result = recover(hash, v, r, s);
    }
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address result)
    {
        assembly {
            let m := mload(0x40)
            mstore(0x00, hash)
            mstore(0x20, and(v, 0xff))
            mstore(0x40, r)
            mstore(0x60, s)
            pop(
                staticcall(
                    gas(), 
                    lt(s, add(_MALLEABILITY_THRESHOLD, 1)), 
                    0x00, 
                    0x80, 
                    0x00, 
                    0x20 
                )
            )
            result := mload(0x00)
            if iszero(returndatasize()) {
                mstore(0x00, 0x8baa579f)
                revert(0x1c, 0x04)
            }
            mstore(0x60, 0)
            mstore(0x40, m)
        }
    }
    function tryRecover(bytes32 hash, bytes memory signature)
        internal
        view
        returns (address result)
    {
        assembly {
            if iszero(xor(mload(signature), 65)) {
                let m := mload(0x40)
                mstore(0x40, mload(add(signature, 0x20))) 
                let s := mload(add(signature, 0x40))
                mstore(0x60, s)
                if iszero(gt(s, _MALLEABILITY_THRESHOLD)) {
                    mstore(0x00, hash)
                    mstore(0x20, byte(0, mload(add(signature, 0x60))))
                    pop(
                        staticcall(
                            gas(), 
                            0x01, 
                            0x00, 
                            0x80, 
                            0x40, 
                            0x20 
                        )
                    )
                    mstore(0x60, 0)
                    result := mload(xor(0x60, returndatasize()))
                }
                mstore(0x40, m)
            }
        }
    }
    function tryRecoverCalldata(bytes32 hash, bytes calldata signature)
        internal
        view
        returns (address result)
    {
        assembly {
            if iszero(xor(signature.length, 65)) {
                let m := mload(0x40)
                calldatacopy(0x40, signature.offset, 0x40)
                if iszero(gt(mload(0x60), _MALLEABILITY_THRESHOLD)) {
                    mstore(0x00, hash)
                    mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40))))
                    pop(
                        staticcall(
                            gas(), 
                            0x01, 
                            0x00, 
                            0x80, 
                            0x40, 
                            0x20 
                        )
                    )
                    mstore(0x60, 0)
                    result := mload(xor(0x60, returndatasize()))
                }
                mstore(0x40, m)
            }
        }
    }
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (address result)
    {
        uint8 v;
        bytes32 s;
        assembly {
            s := shr(1, shl(1, vs))
            v := add(shr(255, vs), 27)
        }
        result = tryRecover(hash, v, r, s);
    }
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (address result)
    {
        assembly {
            let m := mload(0x40)
            if iszero(gt(s, _MALLEABILITY_THRESHOLD)) {
                mstore(0x00, hash)
                mstore(0x20, and(v, 0xff))
                mstore(0x40, r)
                mstore(0x60, s)
                pop(
                    staticcall(
                        gas(), 
                        0x01, 
                        0x00, 
                        0x80, 
                        0x40, 
                        0x20 
                    )
                )
                mstore(0x60, 0)
                result := mload(xor(0x60, returndatasize()))
            }
            mstore(0x40, m)
        }
    }
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        assembly {
            mstore(0x20, hash)
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            result := keccak256(0x04, 0x3c)
        }
    }
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        assembly {
            let m := mload(sub(s, 0x20))
            let sLength := mload(s)
            let ptr := add(s, 0x20)
            let w := not(0)
            let end := add(ptr, sLength)
            for { let temp := sLength } 1 {} {
                ptr := add(ptr, w) 
                mstore8(ptr, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            mstore(sub(ptr, 0x20), "\x00\x00\x00\x00\x00\x00\x19Ethereum Signed Message:\n")
            result := keccak256(sub(ptr, 0x1a), sub(end, sub(ptr, 0x1a)))
            mstore(s, sLength)
            mstore(sub(s, 0x20), m)
        }
    }
    function emptySignature() internal pure returns (bytes calldata signature) {
        assembly {
            signature.length := 0
        }
    }
}