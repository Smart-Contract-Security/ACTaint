pragma solidity ^0.8.4;
import "../math/SafeCast.sol";
library DoubleEndedQueue {
    error Empty();
    error OutOfBounds();
    struct Bytes32Deque {
        int128 _begin;
        int128 _end;
        mapping(int128 => bytes32) _data;
    }
    function pushBack(Bytes32Deque storage deque, bytes32 value) internal {
        int128 backIndex = deque._end;
        deque._data[backIndex] = value;
        unchecked {
            deque._end = backIndex + 1;
        }
    }
    function popBack(Bytes32Deque storage deque) internal returns (bytes32 value) {
        if (empty(deque)) revert Empty();
        int128 backIndex;
        unchecked {
            backIndex = deque._end - 1;
        }
        value = deque._data[backIndex];
        delete deque._data[backIndex];
        deque._end = backIndex;
    }
    function pushFront(Bytes32Deque storage deque, bytes32 value) internal {
        int128 frontIndex;
        unchecked {
            frontIndex = deque._begin - 1;
        }
        deque._data[frontIndex] = value;
        deque._begin = frontIndex;
    }
    function popFront(Bytes32Deque storage deque) internal returns (bytes32 value) {
        if (empty(deque)) revert Empty();
        int128 frontIndex = deque._begin;
        value = deque._data[frontIndex];
        delete deque._data[frontIndex];
        unchecked {
            deque._begin = frontIndex + 1;
        }
    }
    function front(Bytes32Deque storage deque) internal view returns (bytes32 value) {
        if (empty(deque)) revert Empty();
        int128 frontIndex = deque._begin;
        return deque._data[frontIndex];
    }
    function back(Bytes32Deque storage deque) internal view returns (bytes32 value) {
        if (empty(deque)) revert Empty();
        int128 backIndex;
        unchecked {
            backIndex = deque._end - 1;
        }
        return deque._data[backIndex];
    }
    function at(Bytes32Deque storage deque, uint256 index) internal view returns (bytes32 value) {
        int128 idx = SafeCast.toInt128(int256(deque._begin) + SafeCast.toInt256(index));
        if (idx >= deque._end) revert OutOfBounds();
        return deque._data[idx];
    }
    function clear(Bytes32Deque storage deque) internal {
        deque._begin = 0;
        deque._end = 0;
    }
    function length(Bytes32Deque storage deque) internal view returns (uint256) {
        unchecked {
            return uint256(int256(deque._end) - int256(deque._begin));
        }
    }
    function empty(Bytes32Deque storage deque) internal view returns (bool) {
        return deque._end <= deque._begin;
    }
}