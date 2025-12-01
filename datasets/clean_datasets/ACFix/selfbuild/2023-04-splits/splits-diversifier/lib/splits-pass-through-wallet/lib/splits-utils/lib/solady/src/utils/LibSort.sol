pragma solidity ^0.8.4;
library LibSort {
    function insertionSort(uint256[] memory a) internal pure {
        assembly {
            let n := mload(a) 
            mstore(a, 0) 
            let h := add(a, shl(5, n)) 
            let s := 0x20
            let w := not(31)
            for { let i := add(a, s) } 1 {} {
                i := add(i, s)
                if gt(i, h) { break }
                let k := mload(i) 
                let j := add(i, w) 
                let v := mload(j) 
                if iszero(gt(v, k)) { continue }
                for {} 1 {} {
                    mstore(add(j, s), v)
                    j := add(j, w) 
                    v := mload(j)
                    if iszero(gt(v, k)) { break }
                }
                mstore(add(j, s), k)
            }
            mstore(a, n) 
        }
    }
    function insertionSort(int256[] memory a) internal pure {
        _convertTwosComplement(a);
        insertionSort(_toUints(a));
        _convertTwosComplement(a);
    }
    function insertionSort(address[] memory a) internal pure {
        insertionSort(_toUints(a));
    }
    function sort(uint256[] memory a) internal pure {
        assembly {
            let w := not(31)
            let s := 0x20
            let n := mload(a) 
            mstore(a, 0) 
            let stack := mload(0x40)
            for {} iszero(lt(n, 2)) {} {
                let l := add(a, s)
                let h := add(a, shl(5, n))
                let j := l
                for {} iszero(or(eq(j, h), gt(mload(j), mload(add(j, s))))) {} {
                    j := add(j, s)
                }
                if eq(j, h) { break }
                j := h
                for {} iszero(gt(mload(j), mload(add(j, w)))) {} {
                    j := add(j, w) 
                }
                if eq(j, l) {
                    for {} 1 {} {
                        let t := mload(l)
                        mstore(l, mload(h))
                        mstore(h, t)
                        h := add(h, w) 
                        l := add(l, s)
                        if iszero(lt(l, h)) { break }
                    }
                    break
                }
                mstore(stack, l)
                mstore(add(stack, s), h)
                stack := add(stack, 0x40)
                break
            }
            for { let stackBottom := mload(0x40) } iszero(eq(stack, stackBottom)) {} {
                stack := sub(stack, 0x40)
                let l := mload(stack)
                let h := mload(add(stack, s))
                if iszero(gt(sub(h, l), 0x180)) {
                    let i := add(l, s)
                    if iszero(lt(mload(l), mload(i))) {
                        let t := mload(i)
                        mstore(i, mload(l))
                        mstore(l, t)
                    }
                    for {} 1 {} {
                        i := add(i, s)
                        if gt(i, h) { break }
                        let k := mload(i) 
                        let j := add(i, w) 
                        let v := mload(j) 
                        if iszero(gt(v, k)) { continue }
                        for {} 1 {} {
                            mstore(add(j, s), v)
                            j := add(j, w)
                            v := mload(j)
                            if iszero(gt(v, k)) { break }
                        }
                        mstore(add(j, s), k)
                    }
                    continue
                }
                let p := add(shl(5, shr(6, add(l, h))), and(31, l))
                {
                    let e0 := mload(l)
                    let e2 := mload(h)
                    let e1 := mload(p)
                    if iszero(lt(e0, e1)) {
                        let t := e0
                        e0 := e1
                        e1 := t
                    }
                    if iszero(lt(e0, e2)) {
                        let t := e0
                        e0 := e2
                        e2 := t
                    }
                    if iszero(lt(e1, e2)) {
                        let t := e1
                        e1 := e2
                        e2 := t
                    }
                    mstore(p, e1)
                    mstore(h, e2)
                    mstore(l, e0)
                }
                {
                    let x := mload(p)
                    p := h
                    for { let i := l } 1 {} {
                        for {} 1 {} {
                            i := add(i, s)
                            if iszero(gt(x, mload(i))) { break }
                        }
                        let j := p
                        for {} 1 {} {
                            j := add(j, w)
                            if iszero(lt(x, mload(j))) { break }
                        }
                        p := j
                        if iszero(lt(i, p)) { break }
                        let t := mload(i)
                        mstore(i, mload(p))
                        mstore(p, t)
                    }
                }
                {
                    mstore(stack, add(p, s))
                    stack := add(stack, shl(6, lt(add(p, s), h)))
                }
                {
                    mstore(stack, l)
                    mstore(add(stack, s), p)
                    stack := add(stack, shl(6, gt(p, l)))
                }
            }
            mstore(a, n) 
        }
    }
    function sort(int256[] memory a) internal pure {
        _convertTwosComplement(a);
        sort(_toUints(a));
        _convertTwosComplement(a);
    }
    function sort(address[] memory a) internal pure {
        sort(_toUints(a));
    }
    function uniquifySorted(uint256[] memory a) internal pure {
        assembly {
            if iszero(lt(mload(a), 2)) {
                let x := add(a, 0x20)
                let y := add(a, 0x40)
                let end := add(a, shl(5, add(mload(a), 1)))
                for {} 1 {} {
                    if iszero(eq(mload(x), mload(y))) {
                        x := add(x, 0x20)
                        mstore(x, mload(y))
                    }
                    y := add(y, 0x20)
                    if eq(y, end) { break }
                }
                mstore(a, shr(5, sub(x, a)))
            }
        }
    }
    function uniquifySorted(int256[] memory a) internal pure {
        uniquifySorted(_toUints(a));
    }
    function uniquifySorted(address[] memory a) internal pure {
        uniquifySorted(_toUints(a));
    }
    function searchSorted(uint256[] memory a, uint256 needle)
        internal
        pure
        returns (bool found, uint256 index)
    {
        (found, index) = _searchSorted(a, needle, 0);
    }
    function searchSorted(int256[] memory a, int256 needle)
        internal
        pure
        returns (bool found, uint256 index)
    {
        (found, index) = _searchSorted(_toUints(a), uint256(needle), 1 << 255);
    }
    function searchSorted(address[] memory a, address needle)
        internal
        pure
        returns (bool found, uint256 index)
    {
        (found, index) = _searchSorted(_toUints(a), uint256(uint160(needle)), 0);
    }
    function reverse(uint256[] memory a) internal pure {
        assembly {
            if iszero(lt(mload(a), 2)) {
                let s := 0x20
                let w := not(31)
                let h := add(a, shl(5, mload(a)))
                for { a := add(a, s) } 1 {} {
                    let t := mload(a)
                    mstore(a, mload(h))
                    mstore(h, t)
                    h := add(h, w)
                    a := add(a, s)
                    if iszero(lt(a, h)) { break }
                }
            }
        }
    }
    function reverse(int256[] memory a) internal pure {
        reverse(_toUints(a));
    }
    function reverse(address[] memory a) internal pure {
        reverse(_toUints(a));
    }
    function isSorted(uint256[] memory a) internal pure returns (bool result) {
        assembly {
            result := 1
            if iszero(lt(mload(a), 2)) {
                let end := add(a, shl(5, mload(a)))
                for { a := add(a, 0x20) } 1 {} {
                    let p := mload(a)
                    a := add(a, 0x20)
                    result := iszero(gt(p, mload(a)))
                    if iszero(mul(result, xor(a, end))) { break }
                }
            }
        }
    }
    function isSorted(int256[] memory a) internal pure returns (bool result) {
        assembly {
            result := 1
            if iszero(lt(mload(a), 2)) {
                let end := add(a, shl(5, mload(a)))
                for { a := add(a, 0x20) } 1 {} {
                    let p := mload(a)
                    a := add(a, 0x20)
                    result := iszero(sgt(p, mload(a)))
                    if iszero(mul(result, xor(a, end))) { break }
                }
            }
        }
    }
    function isSorted(address[] memory a) internal pure returns (bool result) {
        result = isSorted(_toUints(a));
    }
    function isSortedAndUniquified(uint256[] memory a) internal pure returns (bool result) {
        assembly {
            result := 1
            if iszero(lt(mload(a), 2)) {
                let end := add(a, shl(5, mload(a)))
                for { a := add(a, 0x20) } 1 {} {
                    let p := mload(a)
                    a := add(a, 0x20)
                    result := lt(p, mload(a))
                    if iszero(mul(result, xor(a, end))) { break }
                }
            }
        }
    }
    function isSortedAndUniquified(int256[] memory a) internal pure returns (bool result) {
        assembly {
            result := 1
            if iszero(lt(mload(a), 2)) {
                let end := add(a, shl(5, mload(a)))
                for { a := add(a, 0x20) } 1 {} {
                    let p := mload(a)
                    a := add(a, 0x20)
                    result := slt(p, mload(a))
                    if iszero(mul(result, xor(a, end))) { break }
                }
            }
        }
    }
    function isSortedAndUniquified(address[] memory a) internal pure returns (bool result) {
        result = isSortedAndUniquified(_toUints(a));
    }
    function difference(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory c)
    {
        c = _difference(a, b, 0);
    }
    function difference(int256[] memory a, int256[] memory b)
        internal
        pure
        returns (int256[] memory c)
    {
        c = _toInts(_difference(_toUints(a), _toUints(b), 1 << 255));
    }
    function difference(address[] memory a, address[] memory b)
        internal
        pure
        returns (address[] memory c)
    {
        c = _toAddresses(_difference(_toUints(a), _toUints(b), 0));
    }
    function intersection(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory c)
    {
        c = _intersection(a, b, 0);
    }
    function intersection(int256[] memory a, int256[] memory b)
        internal
        pure
        returns (int256[] memory c)
    {
        c = _toInts(_intersection(_toUints(a), _toUints(b), 1 << 255));
    }
    function intersection(address[] memory a, address[] memory b)
        internal
        pure
        returns (address[] memory c)
    {
        c = _toAddresses(_intersection(_toUints(a), _toUints(b), 0));
    }
    function union(uint256[] memory a, uint256[] memory b)
        internal
        pure
        returns (uint256[] memory c)
    {
        c = _union(a, b, 0);
    }
    function union(int256[] memory a, int256[] memory b)
        internal
        pure
        returns (int256[] memory c)
    {
        c = _toInts(_union(_toUints(a), _toUints(b), 1 << 255));
    }
    function union(address[] memory a, address[] memory b)
        internal
        pure
        returns (address[] memory c)
    {
        c = _toAddresses(_union(_toUints(a), _toUints(b), 0));
    }
    function _toUints(int256[] memory a) private pure returns (uint256[] memory casted) {
        assembly {
            casted := a
        }
    }
    function _toUints(address[] memory a) private pure returns (uint256[] memory casted) {
        assembly {
            casted := a
        }
    }
    function _toInts(uint256[] memory a) private pure returns (int256[] memory casted) {
        assembly {
            casted := a
        }
    }
    function _toAddresses(uint256[] memory a) private pure returns (address[] memory casted) {
        assembly {
            casted := a
        }
    }
    function _convertTwosComplement(int256[] memory a) private pure {
        assembly {
            let w := shl(255, 1)
            for { let end := add(a, shl(5, mload(a))) } iszero(eq(a, end)) {} {
                a := add(a, 0x20)
                mstore(a, add(mload(a), w))
            }
        }
    }
    function _searchSorted(uint256[] memory a, uint256 needle, uint256 signed)
        private
        pure
        returns (bool found, uint256 index)
    {
        assembly {
            let m := 0 
            let s := 0x20
            let l := add(a, s) 
            let h := add(a, shl(5, mload(a))) 
            for { needle := add(signed, needle) } 1 {} {
                m := add(shl(5, shr(6, add(l, h))), and(31, l))
                let t := add(signed, mload(m))
                found := eq(t, needle)
                if or(gt(l, h), found) { break }
                if iszero(gt(needle, t)) {
                    h := sub(m, s)
                    continue
                }
                l := add(m, s)
            }
            let t := iszero(lt(m, add(a, s)))
            index := shr(5, mul(sub(m, add(a, s)), t))
            found := and(found, t)
        }
    }
    function _difference(uint256[] memory a, uint256[] memory b, uint256 signed)
        private
        pure
        returns (uint256[] memory c)
    {
        assembly {
            let s := 0x20
            let aEnd := add(a, shl(5, mload(a)))
            let bEnd := add(b, shl(5, mload(b)))
            c := mload(0x40) 
            a := add(a, s)
            b := add(b, s)
            let k := c
            for {} iszero(or(gt(a, aEnd), gt(b, bEnd))) {} {
                let u := mload(a)
                let v := mload(b)
                if iszero(xor(u, v)) {
                    a := add(a, s)
                    b := add(b, s)
                    continue
                }
                if iszero(lt(add(u, signed), add(v, signed))) {
                    b := add(b, s)
                    continue
                }
                k := add(k, s)
                mstore(k, u)
                a := add(a, s)
            }
            for {} iszero(gt(a, aEnd)) {} {
                k := add(k, s)
                mstore(k, mload(a))
                a := add(a, s)
            }
            mstore(c, shr(5, sub(k, c))) 
            mstore(0x40, add(k, s)) 
        }
    }
    function _intersection(uint256[] memory a, uint256[] memory b, uint256 signed)
        private
        pure
        returns (uint256[] memory c)
    {
        assembly {
            let s := 0x20
            let aEnd := add(a, shl(5, mload(a)))
            let bEnd := add(b, shl(5, mload(b)))
            c := mload(0x40) 
            a := add(a, s)
            b := add(b, s)
            let k := c
            for {} iszero(or(gt(a, aEnd), gt(b, bEnd))) {} {
                let u := mload(a)
                let v := mload(b)
                if iszero(xor(u, v)) {
                    k := add(k, s)
                    mstore(k, u)
                    a := add(a, s)
                    b := add(b, s)
                    continue
                }
                if iszero(lt(add(u, signed), add(v, signed))) {
                    b := add(b, s)
                    continue
                }
                a := add(a, s)
            }
            mstore(c, shr(5, sub(k, c))) 
            mstore(0x40, add(k, s)) 
        }
    }
    function _union(uint256[] memory a, uint256[] memory b, uint256 signed)
        private
        pure
        returns (uint256[] memory c)
    {
        assembly {
            let s := 0x20
            let aEnd := add(a, shl(5, mload(a)))
            let bEnd := add(b, shl(5, mload(b)))
            c := mload(0x40) 
            a := add(a, s)
            b := add(b, s)
            let k := c
            for {} iszero(or(gt(a, aEnd), gt(b, bEnd))) {} {
                let u := mload(a)
                let v := mload(b)
                if iszero(xor(u, v)) {
                    k := add(k, s)
                    mstore(k, u)
                    a := add(a, s)
                    b := add(b, s)
                    continue
                }
                if iszero(lt(add(u, signed), add(v, signed))) {
                    k := add(k, s)
                    mstore(k, v)
                    b := add(b, s)
                    continue
                }
                k := add(k, s)
                mstore(k, u)
                a := add(a, s)
            }
            for {} iszero(gt(a, aEnd)) {} {
                k := add(k, s)
                mstore(k, mload(a))
                a := add(a, s)
            }
            for {} iszero(gt(b, bEnd)) {} {
                k := add(k, s)
                mstore(k, mload(b))
                b := add(b, s)
            }
            mstore(c, shr(5, sub(k, c))) 
            mstore(0x40, add(k, s)) 
        }
    }
}