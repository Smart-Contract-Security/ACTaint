pragma solidity ^0.8.0;
import "./StorageSlot.sol";
import "./math/Math.sol";
library Arrays {
    using StorageSlot for bytes32;
    function findUpperBound(uint256[] storage array, uint256 element) internal view returns (uint256) {
        if (array.length == 0) {
            return 0;
        }
        uint256 low = 0;
        uint256 high = array.length;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (unsafeAccess(array, mid).value > element) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }
        if (low > 0 && unsafeAccess(array, low - 1).value == element) {
            return low - 1;
        } else {
            return low;
        }
    }
    function unsafeAccess(address[] storage arr, uint256 pos) internal pure returns (StorageSlot.AddressSlot storage) {
        bytes32 slot;
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getAddressSlot();
    }
    function unsafeAccess(bytes32[] storage arr, uint256 pos) internal pure returns (StorageSlot.Bytes32Slot storage) {
        bytes32 slot;
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getBytes32Slot();
    }
    function unsafeAccess(uint256[] storage arr, uint256 pos) internal pure returns (StorageSlot.Uint256Slot storage) {
        bytes32 slot;
        assembly {
            mstore(0, arr.slot)
            slot := add(keccak256(0, 0x20), pos)
        }
        return slot.getUint256Slot();
    }
}