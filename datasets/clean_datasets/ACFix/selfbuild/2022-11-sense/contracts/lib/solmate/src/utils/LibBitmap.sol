pragma solidity >=0.8.0;
library LibBitmap {
    struct Bitmap {
        mapping(uint256 => uint256) map;
    }
    function get(Bitmap storage bitmap, uint256 index) internal view returns (bool isSet) {
        uint256 value = bitmap.map[index >> 8] & (1 << (index & 0xff));
        assembly {
            isSet := value 
        }
    }
    function set(Bitmap storage bitmap, uint256 index) internal {
        bitmap.map[index >> 8] |= (1 << (index & 0xff));
    }
    function unset(Bitmap storage bitmap, uint256 index) internal {
        bitmap.map[index >> 8] &= ~(1 << (index & 0xff));
    }
    function setTo(
        Bitmap storage bitmap,
        uint256 index,
        bool shouldSet
    ) internal {
        uint256 value = bitmap.map[index >> 8];
        assembly {
            let shift := and(index, 0xff)
            let x := and(shr(shift, value), 1)
            x := xor(x, shouldSet)
            value := xor(value, shl(shift, x))
        }
        bitmap.map[index >> 8] = value;
    }
}