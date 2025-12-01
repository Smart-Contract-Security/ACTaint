pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
library EnumerableSet {
    struct AddressSet {
        address[] _values;
        mapping(address => uint256) _indexes;
    }
    function add(AddressSet storage set, address value) internal returns (bool) {
        if (!contains(set, value)) {
            set._values.push(value);
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }
    function remove(AddressSet storage set, address value) internal returns (bool) {
        uint256 valueIndex = set._indexes[value];
        if (valueIndex != 0) {
            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;
            if (toDeleteIndex != lastIndex) {
                address lastValue = set._values[lastIndex];
                set._values[toDeleteIndex] = lastValue;
                set._indexes[lastValue] = toDeleteIndex + 1; 
            }
            set._values.pop();
            delete set._indexes[value];
            return true;
        } else {
            return false;
        }
    }
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return set._indexes[value] != 0;
    }
    function length(AddressSet storage set) internal view returns (uint256) {
        return set._values.length;
    }
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        _require(set._values.length > index, Errors.OUT_OF_BOUNDS);
        return unchecked_at(set, index);
    }
    function unchecked_at(AddressSet storage set, uint256 index) internal view returns (address) {
        return set._values[index];
    }
    function rawIndexOf(AddressSet storage set, address value) internal view returns (uint256) {
        return set._indexes[value] - 1;
    }
}