pragma solidity ^0.8.4;
library SignatureCheckerLib {
    bytes32 private constant _MALLEABILITY_THRESHOLD =
        0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0;
    function isValidSignatureNow(address signer, bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool isValid)
    {
        assembly {
            for { signer := shr(96, shl(96, signer)) } signer {} {
                let m := mload(0x40)
                let signatureLength := mload(signature)
                if iszero(xor(signatureLength, 65)) {
                    mstore(add(m, 0x40), mload(add(signature, 0x20))) 
                    let s := mload(add(signature, 0x40))
                    mstore(add(m, 0x60), s)
                    if iszero(gt(s, _MALLEABILITY_THRESHOLD)) {
                        mstore(m, hash)
                        mstore(add(m, 0x20), byte(0, mload(add(signature, 0x60))))
                        pop(
                            staticcall(
                                gas(), 
                                0x01, 
                                m, 
                                0x80, 
                                m, 
                                0x20 
                            )
                        )
                        if mul(eq(mload(m), signer), returndatasize()) {
                            isValid := 1
                            break
                        }
                    }
                }
                let f := shl(224, 0x1626ba7e)
                mstore(m, f)
                mstore(add(m, 0x04), hash)
                mstore(add(m, 0x24), 0x40) 
                {
                    let j := add(m, 0x44)
                    mstore(j, signatureLength) 
                    for { let i := 0 } 1 {} {
                        i := add(i, 0x20)
                        mstore(add(j, i), mload(add(signature, i)))
                        if iszero(lt(i, signatureLength)) { break }
                    }
                }
                isValid := and(
                    and(
                        eq(mload(0x00), f),
                        eq(returndatasize(), 0x20)
                    ),
                    staticcall(
                        gas(), 
                        signer, 
                        m, 
                        add(signatureLength, 0x64), 
                        0x00, 
                        0x20 
                    )
                )
                break
            }
        }
    }
    function isValidSignatureNowCalldata(address signer, bytes32 hash, bytes calldata signature)
        internal
        view
        returns (bool isValid)
    {
        assembly {
            for { signer := shr(96, shl(96, signer)) } signer {} {
                let m := mload(0x40)
                if iszero(xor(signature.length, 65)) {
                    calldatacopy(add(m, 0x40), signature.offset, 0x40)
                    if iszero(gt(mload(add(m, 0x60)), _MALLEABILITY_THRESHOLD)) {
                        mstore(m, hash)
                        mstore(add(m, 0x20), byte(0, calldataload(add(signature.offset, 0x40))))
                        pop(
                            staticcall(
                                gas(), 
                                0x01, 
                                m, 
                                0x80, 
                                m, 
                                0x20 
                            )
                        )
                        if mul(eq(mload(m), signer), returndatasize()) {
                            isValid := 1
                            break
                        }
                    }
                }
                let f := shl(224, 0x1626ba7e)
                mstore(m, f)
                mstore(add(m, 0x04), hash)
                mstore(add(m, 0x24), 0x40) 
                mstore(add(m, 0x44), signature.length) 
                calldatacopy(add(m, 0x64), signature.offset, signature.length)
                isValid := and(
                    and(
                        eq(mload(0x00), f),
                        eq(returndatasize(), 0x20)
                    ),
                    staticcall(
                        gas(), 
                        signer, 
                        m, 
                        add(signature.length, 0x64), 
                        0x00, 
                        0x20 
                    )
                )
                break
            }
        }
    }
    function isValidSignatureNow(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool isValid)
    {
        uint8 v;
        bytes32 s;
        assembly {
            s := shr(1, shl(1, vs))
            v := add(shr(255, vs), 27)
        }
        isValid = isValidSignatureNow(signer, hash, v, r, s);
    }
    function isValidSignatureNow(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool isValid)
    {
        assembly {
            for { signer := shr(96, shl(96, signer)) } signer {} {
                let m := mload(0x40)
                v := and(v, 0xff)
                if iszero(gt(s, _MALLEABILITY_THRESHOLD)) {
                    mstore(m, hash)
                    mstore(add(m, 0x20), v)
                    mstore(add(m, 0x40), r)
                    mstore(add(m, 0x60), s)
                    pop(
                        staticcall(
                            gas(), 
                            0x01, 
                            m, 
                            0x80, 
                            m, 
                            0x20 
                        )
                    )
                    if mul(eq(mload(m), signer), returndatasize()) {
                        isValid := 1
                        break
                    }
                }
                let f := shl(224, 0x1626ba7e)
                mstore(m, f) 
                mstore(add(m, 0x04), hash)
                mstore(add(m, 0x24), 0x40) 
                mstore(add(m, 0x44), 65) 
                mstore(add(m, 0x64), r) 
                mstore(add(m, 0x84), s) 
                mstore8(add(m, 0xa4), v) 
                isValid := and(
                    and(
                        eq(mload(0x00), f),
                        eq(returndatasize(), 0x20)
                    ),
                    staticcall(
                        gas(), 
                        signer, 
                        m, 
                        0xa5, 
                        0x00, 
                        0x20 
                    )
                )
                break
            }
        }
    }
    function isValidERC1271SignatureNow(address signer, bytes32 hash, bytes memory signature)
        internal
        view
        returns (bool isValid)
    {
        assembly {
            let m := mload(0x40)
            let signatureLength := mload(signature)
            let f := shl(224, 0x1626ba7e)
            mstore(m, f)
            mstore(add(m, 0x04), hash)
            mstore(add(m, 0x24), 0x40) 
            {
                let j := add(m, 0x44)
                mstore(j, signatureLength) 
                for { let i := 0 } 1 {} {
                    i := add(i, 0x20)
                    mstore(add(j, i), mload(add(signature, i)))
                    if iszero(lt(i, signatureLength)) { break }
                }
            }
            isValid := and(
                and(
                    eq(mload(0x00), f),
                    eq(returndatasize(), 0x20)
                ),
                staticcall(
                    gas(), 
                    signer, 
                    m, 
                    add(signatureLength, 0x64), 
                    0x00, 
                    0x20 
                )
            )
        }
    }
    function isValidERC1271SignatureNowCalldata(
        address signer,
        bytes32 hash,
        bytes calldata signature
    ) internal view returns (bool isValid) {
        assembly {
            let m := mload(0x40)
            let f := shl(224, 0x1626ba7e)
            mstore(m, f)
            mstore(add(m, 0x04), hash)
            mstore(add(m, 0x24), 0x40) 
            mstore(add(m, 0x44), signature.length) 
            calldatacopy(add(m, 0x64), signature.offset, signature.length)
            isValid := and(
                and(
                    eq(mload(0x00), f),
                    eq(returndatasize(), 0x20)
                ),
                staticcall(
                    gas(), 
                    signer, 
                    m, 
                    add(signature.length, 0x64), 
                    0x00, 
                    0x20 
                )
            )
        }
    }
    function isValidERC1271SignatureNow(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool isValid)
    {
        uint8 v;
        bytes32 s;
        assembly {
            s := shr(1, shl(1, vs))
            v := add(shr(255, vs), 27)
        }
        isValid = isValidERC1271SignatureNow(signer, hash, v, r, s);
    }
    function isValidERC1271SignatureNow(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool isValid)
    {
        assembly {
            let m := mload(0x40)
            let f := shl(224, 0x1626ba7e)
            mstore(m, f) 
            mstore(add(m, 0x04), hash)
            mstore(add(m, 0x24), 0x40) 
            mstore(add(m, 0x44), 65) 
            mstore(add(m, 0x64), r) 
            mstore(add(m, 0x84), s) 
            mstore8(add(m, 0xa4), v) 
            isValid := and(
                and(
                    eq(mload(0x00), f),
                    eq(returndatasize(), 0x20)
                ),
                staticcall(
                    gas(), 
                    signer, 
                    m, 
                    0xa5, 
                    0x00, 
                    0x20 
                )
            )
        }
    }
    function emptySignature() internal pure returns (bytes calldata signature) {
        assembly {
            signature.length := 0
        }
    }
}