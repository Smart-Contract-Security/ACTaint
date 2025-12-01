pragma solidity ^0.8.4;
library Base64 {
    function encode(bytes memory data, bool fileSafe, bool noPadding)
        internal
        pure
        returns (string memory result)
    {
        assembly {
            let dataLength := mload(data)
            if dataLength {
                let encodedLength := shl(2, div(add(dataLength, 2), 3))
                result := mload(0x40)
                mstore(0x1f, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef")
                mstore(0x3f, sub("ghijklmnopqrstuvwxyz0123456789-_", mul(iszero(fileSafe), 0x0230)))
                let ptr := add(result, 0x20)
                let end := add(ptr, encodedLength)
                for {} 1 {} {
                    data := add(data, 3) 
                    let input := mload(data)
                    mstore8(0, mload(and(shr(18, input), 0x3F)))
                    mstore8(1, mload(and(shr(12, input), 0x3F)))
                    mstore8(2, mload(and(shr(6, input), 0x3F)))
                    mstore8(3, mload(and(input, 0x3F)))
                    mstore(ptr, mload(0x00))
                    ptr := add(ptr, 4) 
                    if iszero(lt(ptr, end)) { break }
                }
                mstore(0x40, and(add(end, 31), not(31)))
                let o := div(2, mod(dataLength, 3))
                mstore(sub(ptr, o), shl(240, 0x3d3d))
                o := mul(iszero(iszero(noPadding)), o)
                mstore(sub(ptr, o), 0)
                mstore(result, sub(encodedLength, o))
            }
        }
    }
    function encode(bytes memory data) internal pure returns (string memory result) {
        result = encode(data, false, false);
    }
    function encode(bytes memory data, bool fileSafe)
        internal
        pure
        returns (string memory result)
    {
        result = encode(data, fileSafe, false);
    }
    function decode(string memory data) internal pure returns (bytes memory result) {
        assembly {
            let dataLength := mload(data)
            if dataLength {
                let decodedLength := mul(shr(2, dataLength), 3)
                for {} 1 {} {
                    if iszero(and(dataLength, 3)) {
                        let t := xor(mload(add(data, dataLength)), 0x3d3d)
                        decodedLength := sub(
                            decodedLength,
                            add(iszero(byte(30, t)), iszero(byte(31, t)))
                        )
                        break
                    }
                    decodedLength := add(decodedLength, sub(and(dataLength, 3), 1))
                    break
                }
                result := mload(0x40)
                mstore(result, decodedLength)
                let ptr := add(result, 0x20)
                let end := add(ptr, decodedLength)
                let m := 0xfc000000fc00686c7074787c8084888c9094989ca0a4a8acb0b4b8bcc0c4c8cc
                mstore(0x5b, m)
                mstore(0x3b, 0x04080c1014181c2024282c3034383c4044484c5054585c6064)
                mstore(0x1a, 0xf8fcf800fcd0d4d8dce0e4e8ecf0f4)
                for {} 1 {} {
                    data := add(data, 4)
                    let input := mload(data)
                    mstore(ptr, or(
                        and(m, mload(byte(28, input))),
                        shr(6, or(
                            and(m, mload(byte(29, input))),
                            shr(6, or(
                                and(m, mload(byte(30, input))),
                                shr(6, mload(byte(31, input)))
                            ))
                        ))
                    ))
                    ptr := add(ptr, 3)
                    if iszero(lt(ptr, end)) { break }
                }
                mstore(0x40, and(add(end, 31), not(31)))
                mstore(end, 0)
                mstore(0x60, 0)
            }
        }
    }
}