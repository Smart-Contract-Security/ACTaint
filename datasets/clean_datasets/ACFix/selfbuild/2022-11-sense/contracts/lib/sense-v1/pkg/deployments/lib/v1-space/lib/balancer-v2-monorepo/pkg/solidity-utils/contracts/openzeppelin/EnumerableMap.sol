pragma solidity ^0.7.0;
import "./IERC20.sol";
import "../helpers/BalancerErrors.sol";
library EnumerableMap {
    struct IERC20ToBytes32MapEntry {
        IERC20 _key;
        bytes32 _value;
    }
    struct IERC20ToBytes32Map {
        uint256 _length;
        mapping(uint256 => IERC20ToBytes32MapEntry) _entries;
        mapping(IERC20 => uint256) _indexes;
    }
    function set(
        IERC20ToBytes32Map storage map,
        IERC20 key,
        bytes32 value
    ) internal returns (bool) {
        uint256 keyIndex = map._indexes[key];
        if (keyIndex == 0) {
            uint256 previousLength = map._length;
            map._entries[previousLength] = IERC20ToBytes32MapEntry({ _key: key, _value: value });
            map._length = previousLength + 1;
            map._indexes[key] = previousLength + 1;
            return true;
        } else {
            map._entries[keyIndex - 1]._value = value;
            return false;
        }
    }
    function unchecked_setAt(
        IERC20ToBytes32Map storage map,
        uint256 index,
        bytes32 value
    ) internal {
        map._entries[index]._value = value;
    }
    function remove(IERC20ToBytes32Map storage map, IERC20 key) internal returns (bool) {
        uint256 keyIndex = map._indexes[key];
        if (keyIndex != 0) {
            uint256 toDeleteIndex = keyIndex - 1;
            uint256 lastIndex = map._length - 1;
            if (toDeleteIndex != lastIndex) {
                IERC20ToBytes32MapEntry storage lastEntry = map._entries[lastIndex];
                map._entries[toDeleteIndex] = lastEntry;
                map._indexes[lastEntry._key] = toDeleteIndex + 1; 
            }
            delete map._entries[lastIndex];
            map._length = lastIndex;
            delete map._indexes[key];
            return true;
        } else {
            return false;
        }
    }
    function contains(IERC20ToBytes32Map storage map, IERC20 key) internal view returns (bool) {
        return map._indexes[key] != 0;
    }
    function length(IERC20ToBytes32Map storage map) internal view returns (uint256) {
        return map._length;
    }
    function at(IERC20ToBytes32Map storage map, uint256 index) internal view returns (IERC20, bytes32) {
        _require(map._length > index, Errors.OUT_OF_BOUNDS);
        return unchecked_at(map, index);
    }
    function unchecked_at(IERC20ToBytes32Map storage map, uint256 index) internal view returns (IERC20, bytes32) {
        IERC20ToBytes32MapEntry storage entry = map._entries[index];
        return (entry._key, entry._value);
    }
    function unchecked_valueAt(IERC20ToBytes32Map storage map, uint256 index) internal view returns (bytes32) {
        return map._entries[index]._value;
    }
    function get(
        IERC20ToBytes32Map storage map,
        IERC20 key,
        uint256 errorCode
    ) internal view returns (bytes32) {
        uint256 index = map._indexes[key];
        _require(index > 0, errorCode);
        return unchecked_valueAt(map, index - 1);
    }
    function indexOf(
        IERC20ToBytes32Map storage map,
        IERC20 key,
        uint256 errorCode
    ) internal view returns (uint256) {
        uint256 uncheckedIndex = unchecked_indexOf(map, key);
        _require(uncheckedIndex != 0, errorCode);
        return uncheckedIndex - 1;
    }
    function unchecked_indexOf(IERC20ToBytes32Map storage map, IERC20 key) internal view returns (uint256) {
        return map._indexes[key];
    }
    struct IERC20ToUint256MapEntry {
        IERC20 _key;
        uint256 _value;
    }
    struct IERC20ToUint256Map {
        uint256 _length;
        mapping(uint256 => IERC20ToUint256MapEntry) _entries;
        mapping(IERC20 => uint256) _indexes;
    }
    function set(
        IERC20ToUint256Map storage map,
        IERC20 key,
        uint256 value
    ) internal returns (bool) {
        uint256 keyIndex = map._indexes[key];
        if (keyIndex == 0) {
            uint256 previousLength = map._length;
            map._entries[previousLength] = IERC20ToUint256MapEntry({ _key: key, _value: value });
            map._length = previousLength + 1;
            map._indexes[key] = previousLength + 1;
            return true;
        } else {
            map._entries[keyIndex - 1]._value = value;
            return false;
        }
    }
    function unchecked_setAt(
        IERC20ToUint256Map storage map,
        uint256 index,
        uint256 value
    ) internal {
        map._entries[index]._value = value;
    }
    function remove(IERC20ToUint256Map storage map, IERC20 key) internal returns (bool) {
        uint256 keyIndex = map._indexes[key];
        if (keyIndex != 0) {
            uint256 toDeleteIndex = keyIndex - 1;
            uint256 lastIndex = map._length - 1;
            if (toDeleteIndex != lastIndex) {
                IERC20ToUint256MapEntry storage lastEntry = map._entries[lastIndex];
                map._entries[toDeleteIndex] = lastEntry;
                map._indexes[lastEntry._key] = toDeleteIndex + 1; 
            }
            delete map._entries[lastIndex];
            map._length = lastIndex;
            delete map._indexes[key];
            return true;
        } else {
            return false;
        }
    }
    function contains(IERC20ToUint256Map storage map, IERC20 key) internal view returns (bool) {
        return map._indexes[key] != 0;
    }
    function length(IERC20ToUint256Map storage map) internal view returns (uint256) {
        return map._length;
    }
    function at(IERC20ToUint256Map storage map, uint256 index) internal view returns (IERC20, uint256) {
        _require(map._length > index, Errors.OUT_OF_BOUNDS);
        return unchecked_at(map, index);
    }
    function unchecked_at(IERC20ToUint256Map storage map, uint256 index) internal view returns (IERC20, uint256) {
        IERC20ToUint256MapEntry storage entry = map._entries[index];
        return (entry._key, entry._value);
    }
    function unchecked_valueAt(IERC20ToUint256Map storage map, uint256 index) internal view returns (uint256) {
        return map._entries[index]._value;
    }
    function get(
        IERC20ToUint256Map storage map,
        IERC20 key,
        uint256 errorCode
    ) internal view returns (uint256) {
        uint256 index = map._indexes[key];
        _require(index > 0, errorCode);
        return unchecked_valueAt(map, index - 1);
    }
    function indexOf(
        IERC20ToUint256Map storage map,
        IERC20 key,
        uint256 errorCode
    ) internal view returns (uint256) {
        uint256 uncheckedIndex = unchecked_indexOf(map, key);
        _require(uncheckedIndex != 0, errorCode);
        return uncheckedIndex - 1;
    }
    function unchecked_indexOf(IERC20ToUint256Map storage map, IERC20 key) internal view returns (uint256) {
        return map._indexes[key];
    }
}