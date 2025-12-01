pragma solidity ^0.8.4;
library LibString {
    error HexLengthInsufficient();
    uint256 internal constant NOT_FOUND = type(uint256).max;
    function toString(uint256 value) internal pure returns (string memory str) {
        assembly {
            str := add(mload(0x40), 0x80)
            mstore(0x40, add(str, 0x20))
            mstore(str, 0)
            let end := str
            let w := not(0) 
            for { let temp := value } 1 {} {
                str := add(str, w) 
                mstore8(str, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                if iszero(temp) { break }
            }
            let length := sub(end, str)
            str := sub(str, 0x20)
            mstore(str, length)
        }
    }
    function toString(int256 value) internal pure returns (string memory str) {
        if (value >= 0) {
            return toString(uint256(value));
        }
        unchecked {
            str = toString(uint256(-value));
        }
        assembly {
            let length := mload(str) 
            mstore(str, 0x2d) 
            str := sub(str, 1) 
            mstore(str, add(length, 1)) 
        }
    }
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value, length);
        assembly {
            let strLength := add(mload(str), 2) 
            mstore(str, 0x3078) 
            str := sub(str, 2) 
            mstore(str, strLength) 
        }
    }
    function toHexStringNoPrefix(uint256 value, uint256 length)
        internal
        pure
        returns (string memory str)
    {
        assembly {
            str := add(mload(0x40), and(add(shl(1, length), 0x42), not(0x1f)))
            mstore(0x40, add(str, 0x20))
            mstore(str, 0)
            let end := str
            mstore(0x0f, 0x30313233343536373839616263646566)
            let start := sub(str, add(length, length))
            let w := not(1) 
            let temp := value
            for {} 1 {} {
                str := add(str, w) 
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(xor(str, start)) { break }
            }
            if temp {
                mstore(0x00, 0x2194895a)
                revert(0x1c, 0x04)
            }
            let strLength := sub(end, str)
            str := sub(str, 0x20)
            mstore(str, strLength)
        }
    }
    function toHexString(uint256 value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        assembly {
            let strLength := add(mload(str), 2) 
            mstore(str, 0x3078) 
            str := sub(str, 2) 
            mstore(str, strLength) 
        }
    }
    function toHexStringNoPrefix(uint256 value) internal pure returns (string memory str) {
        assembly {
            str := add(mload(0x40), 0x80)
            mstore(0x40, add(str, 0x20))
            mstore(str, 0)
            let end := str
            mstore(0x0f, 0x30313233343536373839616263646566)
            let w := not(1) 
            for { let temp := value } 1 {} {
                str := add(str, w) 
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                if iszero(temp) { break }
            }
            let strLength := sub(end, str)
            str := sub(str, 0x20)
            mstore(str, strLength)
        }
    }
    function toHexStringChecksumed(address value) internal pure returns (string memory str) {
        str = toHexString(value);
        assembly {
            let mask := shl(6, div(not(0), 255)) 
            let o := add(str, 0x22)
            let hashed := and(keccak256(o, 40), mul(34, mask)) 
            let t := shl(240, 136) 
            for { let i := 0 } 1 {} {
                mstore(add(i, i), mul(t, byte(i, hashed)))
                i := add(i, 1)
                if eq(i, 20) { break }
            }
            mstore(o, xor(mload(o), shr(1, and(mload(0x00), and(mload(o), mask)))))
            o := add(o, 0x20)
            mstore(o, xor(mload(o), shr(1, and(mload(0x20), and(mload(o), mask)))))
        }
    }
    function toHexString(address value) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(value);
        assembly {
            let strLength := add(mload(str), 2) 
            mstore(str, 0x3078) 
            str := sub(str, 2) 
            mstore(str, strLength) 
        }
    }
    function toHexStringNoPrefix(address value) internal pure returns (string memory str) {
        assembly {
            str := mload(0x40)
            mstore(0x40, add(str, 0x80))
            mstore(0x0f, 0x30313233343536373839616263646566)
            str := add(str, 2)
            mstore(str, 40)
            let o := add(str, 0x20)
            mstore(add(o, 40), 0)
            value := shl(96, value)
            for { let i := 0 } 1 {} {
                let p := add(o, add(i, i))
                let temp := byte(i, value)
                mstore8(add(p, 1), mload(and(temp, 15)))
                mstore8(p, mload(shr(4, temp)))
                i := add(i, 1)
                if eq(i, 20) { break }
            }
        }
    }
    function toHexString(bytes memory raw) internal pure returns (string memory str) {
        str = toHexStringNoPrefix(raw);
        assembly {
            let strLength := add(mload(str), 2) 
            mstore(str, 0x3078) 
            str := sub(str, 2) 
            mstore(str, strLength) 
        }
    }
    function toHexStringNoPrefix(bytes memory raw) internal pure returns (string memory str) {
        assembly {
            let length := mload(raw)
            str := add(mload(0x40), 2) 
            mstore(str, add(length, length)) 
            mstore(0x0f, 0x30313233343536373839616263646566)
            let o := add(str, 0x20)
            let end := add(raw, length)
            for {} iszero(eq(raw, end)) {} {
                raw := add(raw, 1)
                mstore8(add(o, 1), mload(and(mload(raw), 15)))
                mstore8(o, mload(and(shr(4, mload(raw)), 15)))
                o := add(o, 2)
            }
            mstore(o, 0) 
            mstore(0x40, and(add(o, 31), not(31))) 
        }
    }
    function runeCount(string memory s) internal pure returns (uint256 result) {
        assembly {
            if mload(s) {
                mstore(0x00, div(not(0), 255))
                mstore(0x20, 0x0202020202020202020202020202020202020202020202020303030304040506)
                let o := add(s, 0x20)
                let end := add(o, mload(s))
                for { result := 1 } 1 { result := add(result, 1) } {
                    o := add(o, byte(0, mload(shr(250, mload(o)))))
                    if iszero(lt(o, end)) { break }
                }
            }
        }
    }
    function replace(string memory subject, string memory search, string memory replacement)
        internal
        pure
        returns (string memory result)
    {
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)
            let replacementLength := mload(replacement)
            subject := add(subject, 0x20)
            search := add(search, 0x20)
            replacement := add(replacement, 0x20)
            result := add(mload(0x40), 0x20)
            let subjectEnd := add(subject, subjectLength)
            if iszero(gt(searchLength, subjectLength)) {
                let subjectSearchEnd := add(sub(subjectEnd, searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 32)) { h := keccak256(search, searchLength) }
                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(search)
                for {} 1 {} {
                    let t := mload(subject)
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                mstore(result, t)
                                result := add(result, 1)
                                subject := add(subject, 1)
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        for { let o := 0 } 1 {} {
                            mstore(add(result, o), mload(add(replacement, o)))
                            o := add(o, 0x20)
                            if iszero(lt(o, replacementLength)) { break }
                        }
                        result := add(result, replacementLength)
                        subject := add(subject, searchLength)
                        if searchLength {
                            if iszero(lt(subject, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    mstore(result, t)
                    result := add(result, 1)
                    subject := add(subject, 1)
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
            }
            let resultRemainder := result
            result := add(mload(0x40), 0x20)
            let k := add(sub(resultRemainder, result), sub(subjectEnd, subject))
            for {} lt(subject, subjectEnd) {} {
                mstore(resultRemainder, mload(subject))
                resultRemainder := add(resultRemainder, 0x20)
                subject := add(subject, 0x20)
            }
            result := sub(result, 0x20)
            let last := add(add(result, 0x20), k)
            mstore(last, 0)
            mstore(0x40, and(add(last, 31), not(31)))
            mstore(result, k)
        }
    }
    function indexOf(string memory subject, string memory search, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            for { let subjectLength := mload(subject) } 1 {} {
                if iszero(mload(search)) {
                    if iszero(gt(from, subjectLength)) {
                        result := from
                        break
                    }
                    result := subjectLength
                    break
                }
                let searchLength := mload(search)
                let subjectStart := add(subject, 0x20)
                result := not(0) 
                subject := add(subjectStart, from)
                let end := add(sub(add(subjectStart, subjectLength), searchLength), 1)
                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(add(search, 0x20))
                if iszero(and(lt(subject, end), lt(from, subjectLength))) { break }
                if iszero(lt(searchLength, 32)) {
                    for { let h := keccak256(add(search, 0x20), searchLength) } 1 {} {
                        if iszero(shr(m, xor(mload(subject), s))) {
                            if eq(keccak256(subject, searchLength), h) {
                                result := sub(subject, subjectStart)
                                break
                            }
                        }
                        subject := add(subject, 1)
                        if iszero(lt(subject, end)) { break }
                    }
                    break
                }
                for {} 1 {} {
                    if iszero(shr(m, xor(mload(subject), s))) {
                        result := sub(subject, subjectStart)
                        break
                    }
                    subject := add(subject, 1)
                    if iszero(lt(subject, end)) { break }
                }
                break
            }
        }
    }
    function indexOf(string memory subject, string memory search)
        internal
        pure
        returns (uint256 result)
    {
        result = indexOf(subject, search, 0);
    }
    function lastIndexOf(string memory subject, string memory search, uint256 from)
        internal
        pure
        returns (uint256 result)
    {
        assembly {
            for {} 1 {} {
                result := not(0) 
                let searchLength := mload(search)
                if gt(searchLength, mload(subject)) { break }
                let w := result
                let fromMax := sub(mload(subject), searchLength)
                if iszero(gt(fromMax, from)) { from := fromMax }
                let end := add(add(subject, 0x20), w)
                subject := add(add(subject, 0x20), from)
                if iszero(gt(subject, end)) { break }
                for { let h := keccak256(add(search, 0x20), searchLength) } 1 {} {
                    if eq(keccak256(subject, searchLength), h) {
                        result := sub(subject, add(end, 1))
                        break
                    }
                    subject := add(subject, w) 
                    if iszero(gt(subject, end)) { break }
                }
                break
            }
        }
    }
    function lastIndexOf(string memory subject, string memory search)
        internal
        pure
        returns (uint256 result)
    {
        result = lastIndexOf(subject, search, uint256(int256(-1)));
    }
    function startsWith(string memory subject, string memory search)
        internal
        pure
        returns (bool result)
    {
        assembly {
            let searchLength := mload(search)
            result := and(
                iszero(gt(searchLength, mload(subject))),
                eq(
                    keccak256(add(subject, 0x20), searchLength),
                    keccak256(add(search, 0x20), searchLength)
                )
            )
        }
    }
    function endsWith(string memory subject, string memory search)
        internal
        pure
        returns (bool result)
    {
        assembly {
            let searchLength := mload(search)
            let subjectLength := mload(subject)
            let withinRange := iszero(gt(searchLength, subjectLength))
            result := and(
                withinRange,
                eq(
                    keccak256(
                        add(add(subject, 0x20), mul(withinRange, sub(subjectLength, searchLength))),
                        searchLength
                    ),
                    keccak256(add(search, 0x20), searchLength)
                )
            )
        }
    }
    function repeat(string memory subject, uint256 times)
        internal
        pure
        returns (string memory result)
    {
        assembly {
            let subjectLength := mload(subject)
            if iszero(or(iszero(times), iszero(subjectLength))) {
                subject := add(subject, 0x20)
                result := mload(0x40)
                let output := add(result, 0x20)
                for {} 1 {} {
                    for { let o := 0 } 1 {} {
                        mstore(add(output, o), mload(add(subject, o)))
                        o := add(o, 0x20)
                        if iszero(lt(o, subjectLength)) { break }
                    }
                    output := add(output, subjectLength)
                    times := sub(times, 1)
                    if iszero(times) { break }
                }
                mstore(output, 0)
                let resultLength := sub(output, add(result, 0x20))
                mstore(result, resultLength)
                mstore(0x40, add(result, and(add(resultLength, 63), not(31))))
            }
        }
    }
    function slice(string memory subject, uint256 start, uint256 end)
        internal
        pure
        returns (string memory result)
    {
        assembly {
            let subjectLength := mload(subject)
            if iszero(gt(subjectLength, end)) { end := subjectLength }
            if iszero(gt(subjectLength, start)) { start := subjectLength }
            if lt(start, end) {
                result := mload(0x40)
                let resultLength := sub(end, start)
                mstore(result, resultLength)
                subject := add(subject, start)
                let w := not(31)
                for { let o := and(add(resultLength, 31), w) } 1 {} {
                    mstore(add(result, o), mload(add(subject, o)))
                    o := add(o, w) 
                    if iszero(o) { break }
                }
                mstore(add(add(result, 0x20), resultLength), 0)
                mstore(0x40, add(result, and(add(resultLength, 63), w)))
            }
        }
    }
    function slice(string memory subject, uint256 start)
        internal
        pure
        returns (string memory result)
    {
        result = slice(subject, start, uint256(int256(-1)));
    }
    function indicesOf(string memory subject, string memory search)
        internal
        pure
        returns (uint256[] memory result)
    {
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)
            if iszero(gt(searchLength, subjectLength)) {
                subject := add(subject, 0x20)
                search := add(search, 0x20)
                result := add(mload(0x40), 0x20)
                let subjectStart := subject
                let subjectSearchEnd := add(sub(add(subject, subjectLength), searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 32)) { h := keccak256(search, searchLength) }
                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(search)
                for {} 1 {} {
                    let t := mload(subject)
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                subject := add(subject, 1)
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        mstore(result, sub(subject, subjectStart))
                        result := add(result, 0x20)
                        subject := add(subject, searchLength)
                        if searchLength {
                            if iszero(lt(subject, subjectSearchEnd)) { break }
                            continue
                        }
                    }
                    subject := add(subject, 1)
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
                let resultEnd := result
                result := mload(0x40)
                mstore(result, shr(5, sub(resultEnd, add(result, 0x20))))
                mstore(0x40, add(resultEnd, 0x20))
            }
        }
    }
    function split(string memory subject, string memory delimiter)
        internal
        pure
        returns (string[] memory result)
    {
        uint256[] memory indices = indicesOf(subject, delimiter);
        assembly {
            let w := not(31)
            let indexPtr := add(indices, 0x20)
            let indicesEnd := add(indexPtr, shl(5, add(mload(indices), 1)))
            mstore(add(indicesEnd, w), mload(subject))
            mstore(indices, add(mload(indices), 1))
            let prevIndex := 0
            for {} 1 {} {
                let index := mload(indexPtr)
                mstore(indexPtr, 0x60)
                if iszero(eq(index, prevIndex)) {
                    let element := mload(0x40)
                    let elementLength := sub(index, prevIndex)
                    mstore(element, elementLength)
                    for { let o := and(add(elementLength, 31), w) } 1 {} {
                        mstore(add(element, o), mload(add(add(subject, prevIndex), o)))
                        o := add(o, w) 
                        if iszero(o) { break }
                    }
                    mstore(add(add(element, 0x20), elementLength), 0)
                    mstore(0x40, add(element, and(add(elementLength, 63), w)))
                    mstore(indexPtr, element)
                }
                prevIndex := add(index, mload(delimiter))
                indexPtr := add(indexPtr, 0x20)
                if iszero(lt(indexPtr, indicesEnd)) { break }
            }
            result := indices
            if iszero(mload(delimiter)) {
                result := add(indices, 0x20)
                mstore(result, sub(mload(indices), 2))
            }
        }
    }
    function concat(string memory a, string memory b)
        internal
        pure
        returns (string memory result)
    {
        assembly {
            let w := not(31)
            result := mload(0x40)
            let aLength := mload(a)
            for { let o := and(add(mload(a), 32), w) } 1 {} {
                mstore(add(result, o), mload(add(a, o)))
                o := add(o, w) 
                if iszero(o) { break }
            }
            let bLength := mload(b)
            let output := add(result, mload(a))
            for { let o := and(add(bLength, 32), w) } 1 {} {
                mstore(add(output, o), mload(add(b, o)))
                o := add(o, w) 
                if iszero(o) { break }
            }
            let totalLength := add(aLength, bLength)
            let last := add(add(result, 0x20), totalLength)
            mstore(last, 0)
            mstore(result, totalLength)
            mstore(0x40, and(add(last, 31), w))
        }
    }
    function toCase(string memory subject, bool toUpper)
        internal
        pure
        returns (string memory result)
    {
        assembly {
            let length := mload(subject)
            if length {
                result := add(mload(0x40), 0x20)
                subject := add(subject, 1)
                let flags := shl(add(70, shl(5, toUpper)), 67108863)
                let w := not(0)
                for { let o := length } 1 {} {
                    o := add(o, w)
                    let b := and(0xff, mload(add(subject, o)))
                    mstore8(add(result, o), xor(b, and(shr(b, flags), 0x20)))
                    if iszero(o) { break }
                }
                result := mload(0x40)
                mstore(result, length)
                let last := add(add(result, 0x20), length)
                mstore(last, 0)
                mstore(0x40, and(add(last, 31), not(31)))
            }
        }
    }
    function lower(string memory subject) internal pure returns (string memory result) {
        result = toCase(subject, false);
    }
    function upper(string memory subject) internal pure returns (string memory result) {
        result = toCase(subject, true);
    }
    function escapeHTML(string memory s) internal pure returns (string memory result) {
        assembly {
            for {
                let end := add(s, mload(s))
                result := add(mload(0x40), 0x20)
                mstore(0x1f, 0x900094)
                mstore(0x08, 0xc0000000a6ab)
                mstore(0x00, shl(64, 0x2671756f743b26616d703b262333393b266c743b2667743b))
            } iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                if iszero(and(shl(c, 1), 0x500000c400000000)) {
                    mstore8(result, c)
                    result := add(result, 1)
                    continue
                }
                let t := shr(248, mload(c))
                mstore(result, mload(and(t, 31)))
                result := add(result, shr(5, t))
            }
            let last := result
            mstore(last, 0)
            result := mload(0x40)
            mstore(result, sub(last, add(result, 0x20)))
            mstore(0x40, and(add(last, 31), not(31)))
        }
    }
    function escapeJSON(string memory s) internal pure returns (string memory result) {
        assembly {
            for {
                let end := add(s, mload(s))
                result := add(mload(0x40), 0x20)
                mstore(0x15, 0x5c75303030303031323334353637383961626364656662746e006672)
                let e := or(shl(0x22, 1), shl(0x5c, 1))
            } iszero(eq(s, end)) {} {
                s := add(s, 1)
                let c := and(mload(s), 0xff)
                if iszero(lt(c, 0x20)) {
                    if iszero(and(shl(c, 1), e)) {
                        mstore8(result, c)
                        result := add(result, 1)
                        continue
                    }
                    mstore8(result, 0x5c) 
                    mstore8(add(result, 1), c)
                    result := add(result, 2)
                    continue
                }
                if iszero(and(shl(c, 1), 0x3700)) {
                    mstore8(0x1d, mload(shr(4, c))) 
                    mstore8(0x1e, mload(and(c, 15))) 
                    mstore(result, mload(0x19)) 
                    result := add(result, 6)
                    continue
                }
                mstore8(result, 0x5c) 
                mstore8(add(result, 1), mload(add(c, 8)))
                result := add(result, 2)
            }
            let last := result
            mstore(last, 0)
            result := mload(0x40)
            mstore(result, sub(last, add(result, 0x20)))
            mstore(0x40, and(add(last, 31), not(31)))
        }
    }
    function eq(string memory a, string memory b) internal pure returns (bool result) {
        assembly {
            result := eq(keccak256(add(a, 0x20), mload(a)), keccak256(add(b, 0x20), mload(b)))
        }
    }
    function packOne(string memory a) internal pure returns (bytes32 result) {
        assembly {
            result :=
                mul(
                    mload(add(a, 0x1f)),
                    lt(sub(mload(a), 1), 0x1f)
                )
        }
    }
    function unpackOne(bytes32 packed) internal pure returns (string memory result) {
        assembly {
            result := mload(0x40)
            mstore(0x40, add(result, 0x40))
            mstore(result, 0)
            mstore(add(result, 0x1f), packed)
            mstore(add(add(result, 0x20), mload(result)), 0)
        }
    }
    function packTwo(string memory a, string memory b) internal pure returns (bytes32 result) {
        assembly {
            let aLength := mload(a)
            result :=
                mul(
                    or(
                        shl(shl(3, sub(0x1f, aLength)), mload(add(a, aLength))),
                        mload(sub(add(b, 0x1e), aLength))
                    ),
                    lt(sub(add(aLength, mload(b)), 1), 0x1e)
                )
        }
    }
    function unpackTwo(bytes32 packed)
        internal
        pure
        returns (string memory resultA, string memory resultB)
    {
        assembly {
            resultA := mload(0x40)
            resultB := add(resultA, 0x40)
            mstore(0x40, add(resultB, 0x40))
            mstore(resultA, 0)
            mstore(resultB, 0)
            mstore(add(resultA, 0x1f), packed)
            mstore(add(resultB, 0x1f), mload(add(add(resultA, 0x20), mload(resultA))))
            mstore(add(add(resultA, 0x20), mload(resultA)), 0)
            mstore(add(add(resultB, 0x20), mload(resultB)), 0)
        }
    }
    function directReturn(string memory a) internal pure {
        assembly {
            let retStart := sub(a, 0x20)
            let retSize := add(mload(a), 0x40)
            mstore(add(retStart, retSize), 0)
            mstore(retStart, 0x20)
            return(retStart, retSize)
        }
    }
}