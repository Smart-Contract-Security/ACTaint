pragma solidity ^0.8.4;
library MinHeapLib {
    error HeapIsEmpty();
    struct Heap {
        uint256[] data;
    }
    function root(Heap storage heap) internal view returns (uint256 result) {
        assembly {
            if iszero(sload(heap.slot)) {
                mstore(0x00, 0xa6ca772e) 
                revert(0x1c, 0x04) 
            }
            mstore(0x00, heap.slot)
            result := sload(keccak256(0x00, 0x20))
        }
    }
    function length(Heap storage heap) internal view returns (uint256) {
        return heap.data.length;
    }
    function push(Heap storage heap, uint256 value) internal {
        _set(heap, value, 0, 4);
    }
    function pop(Heap storage heap) internal returns (uint256 popped) {
        (,, popped) = _set(heap, 0, 0, 3);
    }
    function pushPop(Heap storage heap, uint256 value) internal returns (uint256 popped) {
        (,, popped) = _set(heap, value, 0, 2);
    }
    function replace(Heap storage heap, uint256 value) internal returns (uint256 popped) {
        (,, popped) = _set(heap, value, 0, 1);
    }
    function enqueue(Heap storage heap, uint256 value, uint256 maxLength)
        internal
        returns (bool success, bool hasPopped, uint256 popped)
    {
        (success, hasPopped, popped) = _set(heap, value, maxLength, 0);
    }
    function _set(Heap storage heap, uint256 value, uint256 maxLength, uint256 mode)
        private
        returns (bool success, bool hasPopped, uint256 popped)
    {
        assembly {
            let n := sload(heap.slot)
            mstore(0x00, heap.slot)
            let sOffset := keccak256(0x00, 0x20)
            let pos := 0
            let childPos := not(0)
            for {} 1 {
                mstore(0x00, 0xa6ca772e) 
                revert(0x1c, 0x04) 
            } {
                if iszero(mode) {
                    if iszero(maxLength) { continue }
                    if iszero(eq(n, maxLength)) {
                        success := 1
                        pos := n
                        sstore(heap.slot, add(pos, 1))
                        childPos := add(childPos, childPos)
                        break
                    }
                    let r := sload(sOffset)
                    if iszero(lt(r, value)) { break }
                    success := 1
                    hasPopped := 1
                    childPos := 1
                    popped := r
                    break
                }
                if eq(mode, 1) {
                    if iszero(n) { continue }
                    popped := sload(sOffset)
                    childPos := 1
                    break
                }
                if eq(mode, 2) {
                    popped := value
                    if iszero(n) { break }
                    let r := sload(sOffset)
                    if iszero(lt(r, value)) { break }
                    popped := r
                    childPos := 1
                    break
                }
                if eq(mode, 3) {
                    if iszero(n) { continue }
                    n := sub(n, 1)
                    sstore(heap.slot, n)
                    value := sload(add(sOffset, n))
                    popped := value
                    if iszero(n) { break }
                    popped := sload(sOffset)
                    childPos := 1
                    break
                }
                {
                    pos := n
                    sstore(heap.slot, add(pos, 1))
                    childPos := add(childPos, childPos)
                    break
                }
            }
            for {} lt(childPos, n) {} {
                let child := sload(add(sOffset, childPos))
                let rightPos := add(childPos, 1)
                let right := sload(add(sOffset, rightPos))
                if iszero(and(lt(rightPos, n), iszero(lt(child, right)))) {
                    right := child
                    rightPos := childPos
                }
                sstore(add(sOffset, pos), right)
                pos := rightPos
                childPos := add(shl(1, pos), 1)
            }
            for {} pos {} {
                let parentPos := shr(1, sub(pos, 1))
                let parent := sload(add(sOffset, parentPos))
                if iszero(lt(value, parent)) { break }
                sstore(add(sOffset, pos), parent)
                pos := parentPos
            }
            if add(childPos, 1) { sstore(add(sOffset, pos), value) }
        }
    }
}