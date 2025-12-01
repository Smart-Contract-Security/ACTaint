pragma solidity ^0.8.4;
library RedBlackTreeLib {
    error ValueIsEmpty();
    error ValueAlreadyExists();
    error ValueDoesNotExist();
    error PointerOutOfBounds();
    error TreeIsFull();
    uint256 internal constant ERROR_VALUE_ALREADY_EXISTS = 0xbb33e6ac;
    uint256 internal constant ERROR_VALUE_DOES_NOT_EXISTS = 0xb113638a;
    uint256 internal constant ERROR_POINTER_OUT_OF_BOUNDS = 0xccd52fbc;
    uint256 internal constant ERROR_TREE_IS_FULL = 0xed732d0c;
    struct Tree {
        uint256 _spacer;
    }
    uint256 private constant _NODES_SLOT_SEED = 0x1dc27bb5462fdadcb;
    uint256 private constant _NODES_SLOT_SHIFT = 32;
    uint256 private constant _BITMASK_KEY = (1 << 31) - 1;
    uint256 private constant _BITPOS_LEFT = 0;
    uint256 private constant _BITPOS_RIGHT = 31;
    uint256 private constant _BITPOS_PARENT = 31 * 2;
    uint256 private constant _BITPOS_RED = 31 * 3;
    uint256 private constant _BITMASK_RED = 1 << (31 * 3);
    uint256 private constant _BITPOS_PACKED_VALUE = 96;
    uint256 private constant _BITMASK_PACKED_VALUE = (1 << 160) - 1;
    uint256 private constant _BIT_FULL_VALUE_SLOT = 1 << 31;
    function size(Tree storage tree) internal view returns (uint256 result) {
        uint256 nodes = _nodes(tree);
        assembly {
            result := and(sload(nodes), _BITMASK_KEY)
        }
    }
    function find(Tree storage tree, uint256 x) internal view returns (bytes32 result) {
        (uint256 nodes,, uint256 key) = _find(tree, x);
        result = _pack(nodes, key);
    }
    function nearest(Tree storage tree, uint256 x) internal view returns (bytes32 result) {
        (uint256 nodes, uint256 cursor, uint256 key) = _find(tree, x);
        unchecked {
            if (cursor == 0) return result; 
            if (key != 0) return _pack(nodes, key); 
            bytes32 a = _pack(nodes, cursor);
            uint256 aValue = value(a);
            bytes32 b = x < aValue ? prev(a) : next(a);
            if (b == bytes32(0)) return a; 
            uint256 bValue = value(b);
            uint256 aDist = x < aValue ? aValue - x : x - aValue;
            uint256 bDist = x < bValue ? bValue - x : x - bValue;
            if (aDist == bDist) return aValue < bValue ? a : b; 
            return aDist < bDist ? a : b;
        }
    }
    function nearestBefore(Tree storage tree, uint256 x) internal view returns (bytes32 result) {
        (uint256 nodes, uint256 cursor, uint256 key) = _find(tree, x);
        if (cursor == 0) return result; 
        if (key != 0) return _pack(nodes, key); 
        bytes32 a = _pack(nodes, cursor);
        return value(a) < x ? a : prev(a);
    }
    function nearestAfter(Tree storage tree, uint256 x) internal view returns (bytes32 result) {
        (uint256 nodes, uint256 cursor, uint256 key) = _find(tree, x);
        if (cursor == 0) return result; 
        if (key != 0) return _pack(nodes, key); 
        bytes32 a = _pack(nodes, cursor);
        return value(a) > x ? a : next(a);
    }
    function exists(Tree storage tree, uint256 x) internal view returns (bool result) {
        (,, uint256 key) = _find(tree, x);
        result = key != 0;
    }
    function insert(Tree storage tree, uint256 x) internal {
        uint256 err = tryInsert(tree, x);
        if (err != 0) _revert(err);
    }
    function tryInsert(Tree storage tree, uint256 x) internal returns (uint256 err) {
        (uint256 nodes, uint256 cursor, uint256 key) = _find(tree, x);
        err = _update(nodes, cursor, key, x, 0);
    }
    function remove(Tree storage tree, uint256 x) internal {
        uint256 err = tryRemove(tree, x);
        if (err != 0) _revert(err);
    }
    function tryRemove(Tree storage tree, uint256 x) internal returns (uint256 err) {
        (uint256 nodes,, uint256 key) = _find(tree, x);
        err = _update(nodes, 0, key, 0, 1);
    }
    function remove(bytes32 ptr) internal {
        uint256 err = tryRemove(ptr);
        if (err != 0) _revert(err);
    }
    function tryRemove(bytes32 ptr) internal returns (uint256 err) {
        (uint256 nodes, uint256 key) = _unpack(ptr);
        err = _update(nodes, 0, key, 0, 1);
    }
    function clear(Tree storage tree) internal {
        uint256 nodes = _nodes(tree);
        assembly {
            let totalNodes := and(sload(nodes), _BITMASK_KEY)
            for { let i := 1 } iszero(gt(i, totalNodes)) { i := add(i, 1) } {
                let ptr := or(nodes, i)
                if iszero(shr(_BITPOS_PACKED_VALUE, sload(ptr))) {
                    sstore(or(ptr, _BIT_FULL_VALUE_SLOT), 0)
                }
                sstore(ptr, 0)
            }
            sstore(nodes, 0)
        }
    }
    function value(bytes32 ptr) internal view returns (uint256 result) {
        if (ptr == bytes32(0)) return result;
        assembly {
            let packed := sload(ptr)
            result := shr(_BITPOS_PACKED_VALUE, packed)
            if iszero(result) { result := sload(or(ptr, _BIT_FULL_VALUE_SLOT)) }
        }
    }
    function first(Tree storage tree) internal view returns (bytes32 result) {
        result = _end(tree, _BITPOS_LEFT);
    }
    function last(Tree storage tree) internal view returns (bytes32 result) {
        result = _end(tree, _BITPOS_RIGHT);
    }
    function next(bytes32 ptr) internal view returns (bytes32 result) {
        result = _step(ptr, _BITPOS_LEFT, _BITPOS_RIGHT);
    }
    function prev(bytes32 ptr) internal view returns (bytes32 result) {
        result = _step(ptr, _BITPOS_RIGHT, _BITPOS_LEFT);
    }
    function isEmpty(bytes32 ptr) internal pure returns (bool result) {
        result = ptr == bytes32(0);
    }
    function _unpack(bytes32 ptr) private pure returns (uint256 nodes, uint256 key) {
        assembly {
            nodes := shl(_NODES_SLOT_SHIFT, shr(_NODES_SLOT_SHIFT, ptr))
            key := and(_BITMASK_KEY, ptr)
        }
    }
    function _pack(uint256 nodes, uint256 key) private pure returns (bytes32 result) {
        assembly {
            result := mul(or(nodes, key), iszero(iszero(key)))
        }
    }
    function _end(Tree storage tree, uint256 L) private view returns (bytes32 result) {
        uint256 nodes = _nodes(tree);
        assembly {
            result := shr(128, sload(nodes))
            if result {
                for {} 1 {} {
                    let packed := sload(or(nodes, result))
                    let left := and(shr(L, packed), _BITMASK_KEY)
                    if iszero(left) { break }
                    result := left
                }
            }
        }
        result = _pack(nodes, uint256(result));
    }
    function _step(bytes32 ptr, uint256 L, uint256 R) private view returns (bytes32 result) {
        if (ptr == bytes32(0)) return ptr;
        (uint256 nodes, uint256 target) = _unpack(ptr);
        assembly {
            let packed := sload(ptr)
            for { result := and(shr(R, packed), _BITMASK_KEY) } 1 {} {
                if iszero(result) {
                    result := and(shr(_BITPOS_PARENT, packed), _BITMASK_KEY)
                    for {} 1 {} {
                        if iszero(result) { break }
                        packed := sload(or(nodes, result))
                        if iszero(eq(target, and(shr(R, packed), _BITMASK_KEY))) { break }
                        target := result
                        result := and(shr(_BITPOS_PARENT, packed), _BITMASK_KEY)
                    }
                    break
                }
                for {} 1 {} {
                    packed := sload(or(nodes, result))
                    let left := and(shr(L, packed), _BITMASK_KEY)
                    if iszero(left) { break }
                    result := left
                }
                break
            }
        }
        result = _pack(nodes, uint256(result));
    }
    function _update(uint256 nodes, uint256 cursor, uint256 key, uint256 x, uint256 mode)
        private
        returns (uint256 err)
    {
        assembly {
            function getKey(packed_, bitpos_) -> index_ {
                index_ := and(shr(bitpos_, packed_), _BITMASK_KEY)
            }
            function setKey(packed_, bitpos_, key_) -> result_ {
                result_ := or(and(not(shl(bitpos_, _BITMASK_KEY)), packed_), shl(bitpos_, key_))
            }
            function setRed(packed_, red_) -> result_ {
                result_ := or(and(not(_BITMASK_RED), packed_), shl(_BITPOS_RED, red_))
            }
            function isRed(packed_) -> red_ {
                red_ := and(_BITMASK_RED, packed_)
            }
            function copyRed(packed_, fromPacked_) -> result_ {
                result_ := or(and(not(_BITMASK_RED), packed_), and(_BITMASK_RED, fromPacked_))
            }
            function rotate(nodes_, key_, L, R) {
                let packed_ := sload(or(nodes_, key_))
                let cursor_ := getKey(packed_, R)
                let parent_ := getKey(packed_, _BITPOS_PARENT)
                let cursorPacked_ := sload(or(nodes_, cursor_))
                let cursorLeft_ := getKey(cursorPacked_, L)
                if cursorLeft_ {
                    let s_ := or(nodes_, cursorLeft_)
                    sstore(s_, setKey(sload(s_), _BITPOS_PARENT, key_))
                }
                for {} 1 {} {
                    if iszero(parent_) {
                        mstore(0x00, cursor_)
                        break
                    }
                    let s_ := or(nodes_, parent_)
                    let parentPacked_ := sload(s_)
                    if eq(key_, getKey(parentPacked_, L)) {
                        sstore(s_, setKey(parentPacked_, L, cursor_))
                        break
                    }
                    sstore(s_, setKey(parentPacked_, R, cursor_))
                    break
                }
                packed_ := setKey(packed_, R, cursorLeft_)
                sstore(or(nodes_, key_), setKey(packed_, _BITPOS_PARENT, cursor_))
                cursorPacked_ := setKey(cursorPacked_, _BITPOS_PARENT, parent_)
                sstore(or(nodes_, cursor_), setKey(cursorPacked_, L, key_))
            }
            function insertFixup(nodes_, key_) {
                for {} 1 {} {
                    if eq(key_, mload(0x00)) { break }
                    let packed_ := sload(or(nodes_, key_))
                    let parent_ := getKey(packed_, _BITPOS_PARENT)
                    let parentPacked_ := sload(or(nodes_, parent_))
                    if iszero(isRed(parentPacked_)) { break }
                    let grandParent_ := getKey(parentPacked_, _BITPOS_PARENT)
                    let grandParentPacked_ := sload(or(nodes_, grandParent_))
                    let R := mul(eq(parent_, getKey(grandParentPacked_, 0)), _BITPOS_RIGHT)
                    let L := xor(R, _BITPOS_RIGHT)
                    let cursor_ := getKey(grandParentPacked_, R)
                    let cursorPacked_ := sload(or(nodes_, cursor_))
                    if iszero(isRed(cursorPacked_)) {
                        if eq(key_, getKey(parentPacked_, R)) {
                            key_ := parent_
                            rotate(nodes_, key_, L, R)
                        }
                        parent_ := getKey(sload(or(nodes_, key_)), _BITPOS_PARENT)
                        parentPacked_ := sload(or(nodes_, parent_))
                        sstore(or(nodes_, parent_), setRed(parentPacked_, 0))
                        grandParent_ := getKey(parentPacked_, _BITPOS_PARENT)
                        let s_ := or(nodes_, grandParent_)
                        sstore(s_, setRed(sload(s_), 1))
                        rotate(nodes_, grandParent_, R, L)
                        continue
                    }
                    sstore(or(nodes_, parent_), setRed(parentPacked_, 0))
                    sstore(or(nodes_, cursor_), setRed(cursorPacked_, 0))
                    sstore(or(nodes_, grandParent_), setRed(grandParentPacked_, 1))
                    key_ := grandParent_
                }
                let root_ := mload(0x00)
                sstore(or(nodes_, root_), setRed(sload(or(nodes_, root_)), 0))
            }
            function insert(nodes_, cursor_, key_, x_) -> err_ {
                if key_ {
                    err_ := ERROR_VALUE_ALREADY_EXISTS
                    leave
                }
                let totalNodes_ := add(shr(128, mload(0x20)), 1)
                if gt(totalNodes_, _BITMASK_KEY) {
                    err_ := ERROR_TREE_IS_FULL
                    leave
                }
                mstore(0x20, shl(128, totalNodes_))
                let packed_ := or(_BITMASK_RED, shl(_BITPOS_PARENT, cursor_))
                let nodePointer_ := or(nodes_, totalNodes_)
                for {} 1 {} {
                    if iszero(gt(x_, _BITMASK_PACKED_VALUE)) {
                        packed_ := or(shl(_BITPOS_PACKED_VALUE, x_), packed_)
                        break
                    }
                    sstore(or(nodePointer_, _BIT_FULL_VALUE_SLOT), x_)
                    break
                }
                sstore(nodePointer_, packed_)
                for {} 1 {} {
                    if iszero(cursor_) {
                        mstore(0x00, totalNodes_)
                        break
                    }
                    let s_ := or(nodes_, cursor_)
                    let cursorPacked_ := sload(s_)
                    let cursorValue_ := shr(_BITPOS_PACKED_VALUE, cursorPacked_)
                    if iszero(cursorValue_) { cursorValue_ := sload(or(s_, _BIT_FULL_VALUE_SLOT)) }
                    if iszero(lt(x_, cursorValue_)) {
                        sstore(s_, setKey(cursorPacked_, _BITPOS_RIGHT, totalNodes_))
                        break
                    }
                    sstore(s_, setKey(cursorPacked_, _BITPOS_LEFT, totalNodes_))
                    break
                }
                insertFixup(nodes_, totalNodes_)
            }
            function removeFixup(nodes_, key_) {
                for {} 1 {} {
                    if eq(key_, mload(0x00)) { break }
                    let packed_ := sload(or(nodes_, key_))
                    if isRed(packed_) { break }
                    let parent_ := getKey(packed_, _BITPOS_PARENT)
                    let parentPacked_ := sload(or(nodes_, parent_))
                    let R := mul(eq(key_, getKey(parentPacked_, 0)), _BITPOS_RIGHT)
                    let L := xor(R, _BITPOS_RIGHT)
                    let cursor_ := getKey(parentPacked_, R)
                    let cursorPacked_ := sload(or(nodes_, cursor_))
                    if isRed(cursorPacked_) {
                        sstore(or(nodes_, cursor_), setRed(cursorPacked_, 0))
                        sstore(or(nodes_, parent_), setRed(parentPacked_, 1))
                        rotate(nodes_, parent_, L, R)
                        cursor_ := getKey(sload(or(nodes_, parent_)), R)
                        cursorPacked_ := sload(or(nodes_, cursor_))
                    }
                    let cursorLeft_ := getKey(cursorPacked_, L)
                    let cursorLeftPacked_ := sload(or(nodes_, cursorLeft_))
                    let cursorRight_ := getKey(cursorPacked_, R)
                    let cursorRightPacked_ := sload(or(nodes_, cursorRight_))
                    if iszero(or(isRed(cursorLeftPacked_), isRed(cursorRightPacked_))) {
                        sstore(or(nodes_, cursor_), setRed(cursorPacked_, 1))
                        key_ := parent_
                        continue
                    }
                    if iszero(isRed(cursorRightPacked_)) {
                        sstore(or(nodes_, cursorLeft_), setRed(cursorLeftPacked_, 0))
                        sstore(or(nodes_, cursor_), setRed(cursorPacked_, 1))
                        rotate(nodes_, cursor_, R, L)
                        cursor_ := getKey(sload(or(nodes_, parent_)), R)
                        cursorPacked_ := sload(or(nodes_, cursor_))
                        cursorRight_ := getKey(cursorPacked_, R)
                        cursorRightPacked_ := sload(or(nodes_, cursorRight_))
                    }
                    parentPacked_ := sload(or(nodes_, parent_))
                    sstore(or(nodes_, cursor_), copyRed(cursorPacked_, parentPacked_))
                    sstore(or(nodes_, parent_), setRed(parentPacked_, 0))
                    sstore(or(nodes_, cursorRight_), setRed(cursorRightPacked_, 0))
                    rotate(nodes_, parent_, L, R)
                    break
                }
                sstore(or(nodes_, key_), setRed(sload(or(nodes_, key_)), 0))
            }
            function removeLast(nodes_, cursor_) {
                let last_ := shr(128, mload(0x20))
                let lastPacked_ := sload(or(nodes_, last_))
                let lastValue_ := shr(_BITPOS_PACKED_VALUE, lastPacked_)
                let lastFullValue_ := 0
                if iszero(lastValue_) {
                    lastValue_ := sload(or(_BIT_FULL_VALUE_SLOT, or(nodes_, last_)))
                    lastFullValue_ := lastValue_
                }
                let cursorPacked_ := sload(or(nodes_, cursor_))
                let cursorValue_ := shr(_BITPOS_PACKED_VALUE, cursorPacked_)
                let cursorFullValue_ := 0
                if iszero(cursorValue_) {
                    cursorValue_ := sload(or(_BIT_FULL_VALUE_SLOT, or(nodes_, cursor_)))
                    cursorFullValue_ := cursorValue_
                }
                if iszero(eq(lastValue_, cursorValue_)) {
                    sstore(or(nodes_, cursor_), lastPacked_)
                    if iszero(eq(lastFullValue_, cursorFullValue_)) {
                        sstore(or(_BIT_FULL_VALUE_SLOT, or(nodes_, cursor_)), lastFullValue_)
                    }
                    for { let lastParent_ := getKey(lastPacked_, _BITPOS_PARENT) } 1 {} {
                        if iszero(lastParent_) {
                            mstore(0x00, cursor_)
                            break
                        }
                        let s_ := or(nodes_, lastParent_)
                        let p_ := sload(s_)
                        let t_ := iszero(eq(last_, getKey(p_, _BITPOS_LEFT)))
                        sstore(s_, setKey(p_, mul(t_, _BITPOS_RIGHT), cursor_))
                        break
                    }
                    let lastRight_ := getKey(lastPacked_, _BITPOS_RIGHT)
                    if lastRight_ {
                        let s_ := or(nodes_, lastRight_)
                        sstore(s_, setKey(sload(s_), _BITPOS_PARENT, cursor_))
                    }
                    let lastLeft_ := getKey(lastPacked_, _BITPOS_LEFT)
                    if lastLeft_ {
                        let s_ := or(nodes_, lastLeft_)
                        sstore(s_, setKey(sload(s_), _BITPOS_PARENT, cursor_))
                    }
                }
                sstore(or(nodes_, last_), 0)
                if lastFullValue_ { sstore(or(_BIT_FULL_VALUE_SLOT, or(nodes_, last_)), 0) }
                mstore(0x20, shl(128, sub(last_, 1)))
            }
            function remove(nodes_, key_) -> err_ {
                let last_ := shr(128, mload(0x20))
                if gt(key_, last_) {
                    err_ := ERROR_POINTER_OUT_OF_BOUNDS
                    leave
                }
                if iszero(key_) {
                    err_ := ERROR_VALUE_DOES_NOT_EXISTS
                    leave
                }
                let cursor_ := 0
                for {} 1 {} {
                    let packed_ := sload(or(nodes_, key_))
                    let left_ := getKey(packed_, _BITPOS_LEFT)
                    let right_ := getKey(packed_, _BITPOS_RIGHT)
                    if iszero(mul(left_, right_)) {
                        cursor_ := key_
                        break
                    }
                    cursor_ := right_
                    for {} 1 {} {
                        let cursorLeft_ := getKey(sload(or(nodes_, cursor_)), _BITPOS_LEFT)
                        if iszero(cursorLeft_) { break }
                        cursor_ := cursorLeft_
                    }
                    break
                }
                let cursorPacked_ := sload(or(nodes_, cursor_))
                let probe_ := getKey(cursorPacked_, _BITPOS_LEFT)
                if iszero(probe_) { probe_ := getKey(cursorPacked_, _BITPOS_RIGHT) }
                for { let yParent_ := getKey(cursorPacked_, _BITPOS_PARENT) } 1 {} {
                    let probeSlot_ := or(nodes_, probe_)
                    sstore(probeSlot_, setKey(sload(probeSlot_), _BITPOS_PARENT, yParent_))
                    if iszero(yParent_) {
                        mstore(0x00, probe_)
                        break
                    }
                    let s_ := or(nodes_, yParent_)
                    let p_ := sload(s_)
                    let t_ := iszero(eq(cursor_, getKey(p_, _BITPOS_LEFT)))
                    sstore(s_, setKey(p_, mul(t_, _BITPOS_RIGHT), probe_))
                    break
                }
                let skipFixup_ := isRed(cursorPacked_)
                if iszero(eq(cursor_, key_)) {
                    let packed_ := sload(or(nodes_, key_))
                    let parent_ := getKey(packed_, _BITPOS_PARENT)
                    for {} 1 {} {
                        if iszero(parent_) {
                            mstore(0x00, cursor_)
                            break
                        }
                        let s_ := or(nodes_, parent_)
                        let p_ := sload(s_)
                        let t_ := iszero(eq(key_, getKey(p_, _BITPOS_LEFT)))
                        sstore(s_, setKey(p_, mul(t_, _BITPOS_RIGHT), cursor_))
                        break
                    }
                    let left_ := getKey(packed_, _BITPOS_LEFT)
                    let leftSlot_ := or(nodes_, left_)
                    sstore(leftSlot_, setKey(sload(leftSlot_), _BITPOS_PARENT, cursor_))
                    let right_ := getKey(packed_, _BITPOS_RIGHT)
                    let rightSlot_ := or(nodes_, right_)
                    sstore(rightSlot_, setKey(sload(rightSlot_), _BITPOS_PARENT, cursor_))
                    let m_ := sub(shl(_BITPOS_PACKED_VALUE, 1), 1)
                    sstore(
                        or(nodes_, cursor_),
                        xor(cursorPacked_, and(xor(packed_, cursorPacked_), m_))
                    )
                    let t_ := cursor_
                    cursor_ := key_
                    key_ := t_
                }
                if iszero(skipFixup_) { removeFixup(nodes_, probe_) }
                removeLast(nodes_, cursor_)
            }
            mstore(0x10, sload(nodes))
            for {} 1 {} {
                if iszero(mode) {
                    err := insert(nodes, cursor, key, x)
                    break
                }
                err := remove(nodes, key)
                break
            }
            sstore(nodes, mload(0x10))
        }
    }
    function _nodes(Tree storage tree) private pure returns (uint256 nodes) {
        assembly {
            mstore(0x20, tree.slot)
            mstore(0x00, _NODES_SLOT_SEED)
            nodes := shl(_NODES_SLOT_SHIFT, keccak256(0x00, 0x40))
        }
    }
    function _find(Tree storage tree, uint256 x)
        private
        view
        returns (uint256 nodes, uint256 cursor, uint256 key)
    {
        if (x == 0) _revert(0xc94f1877); 
        assembly {
            mstore(0x20, tree.slot)
            mstore(0x00, _NODES_SLOT_SEED)
            nodes := shl(_NODES_SLOT_SHIFT, keccak256(0x00, 0x40))
            mstore(0x01, _BITPOS_RIGHT)
            for { let probe := shr(128, sload(nodes)) } probe {} {
                cursor := probe
                let nodePacked := sload(or(nodes, probe))
                let nodeValue := shr(_BITPOS_PACKED_VALUE, nodePacked)
                if iszero(nodeValue) {
                    nodeValue := sload(or(or(nodes, probe), _BIT_FULL_VALUE_SLOT))
                }
                if eq(nodeValue, x) {
                    key := cursor
                    break
                }
                probe := and(shr(mload(gt(x, nodeValue)), nodePacked), _BITMASK_KEY)
            }
        }
    }
    function _revert(uint256 err) private pure {
        assembly {
            mstore(0x00, err)
            revert(0x1c, 0x04)
        }
    }
}