pragma solidity ^0.8.4;
import "./LibBit.sol";
library LibBitmap {
    uint256 internal constant NOT_FOUND = type(uint256).max;
    struct Bitmap {
        mapping(uint256 => uint256) map;
    }
    function get(Bitmap storage bitmap, uint256 index) internal view returns (bool isSet) {
        uint256 b = (bitmap.map[index >> 8] >> (index & 0xff)) & 1;
        assembly {
            isSet := b
        }
    }
    function set(Bitmap storage bitmap, uint256 index) internal {
        bitmap.map[index >> 8] |= (1 << (index & 0xff));
    }
    function unset(Bitmap storage bitmap, uint256 index) internal {
        bitmap.map[index >> 8] &= ~(1 << (index & 0xff));
    }
    function toggle(Bitmap storage bitmap, uint256 index) internal returns (bool newIsSet) {
        assembly {
            mstore(0x00, shr(8, index))
            mstore(0x20, bitmap.slot)
            let storageSlot := keccak256(0x00, 0x40)
            let shift := and(index, 0xff)
            let storageValue := sload(storageSlot)
            let mask := shl(shift, 1)
            storageValue := xor(storageValue, mask)
            newIsSet := iszero(iszero(and(storageValue, mask)))
            sstore(storageSlot, storageValue)
        }
    }
    function setTo(Bitmap storage bitmap, uint256 index, bool shouldSet) internal {
        assembly {
            mstore(0x20, bitmap.slot)
            mstore(0x00, shr(8, index))
            let storageSlot := keccak256(0x00, 0x40)
            let storageValue := sload(storageSlot)
            let shift := and(index, 0xff)
            sstore(
                storageSlot,
                or(and(storageValue, not(shl(shift, 1))), shl(shift, iszero(iszero(shouldSet))))
            )
        }
    }
    function setBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {
        assembly {
            let max := not(0)
            let shift := and(start, 0xff)
            mstore(0x20, bitmap.slot)
            mstore(0x00, shr(8, start))
            if iszero(lt(add(shift, amount), 257)) {
                let storageSlot := keccak256(0x00, 0x40)
                sstore(storageSlot, or(sload(storageSlot), shl(shift, max)))
                let bucket := add(mload(0x00), 1)
                let bucketEnd := add(mload(0x00), shr(8, add(amount, shift)))
                amount := and(add(amount, shift), 0xff)
                shift := 0
                for {} iszero(eq(bucket, bucketEnd)) { bucket := add(bucket, 1) } {
                    mstore(0x00, bucket)
                    sstore(keccak256(0x00, 0x40), max)
                }
                mstore(0x00, bucket)
            }
            let storageSlot := keccak256(0x00, 0x40)
            sstore(storageSlot, or(sload(storageSlot), shl(shift, shr(sub(256, amount), max))))
        }
    }
    function unsetBatch(Bitmap storage bitmap, uint256 start, uint256 amount) internal {
        assembly {
            let shift := and(start, 0xff)
            mstore(0x20, bitmap.slot)
            mstore(0x00, shr(8, start))
            if iszero(lt(add(shift, amount), 257)) {
                let storageSlot := keccak256(0x00, 0x40)
                sstore(storageSlot, and(sload(storageSlot), not(shl(shift, not(0)))))
                let bucket := add(mload(0x00), 1)
                let bucketEnd := add(mload(0x00), shr(8, add(amount, shift)))
                amount := and(add(amount, shift), 0xff)
                shift := 0
                for {} iszero(eq(bucket, bucketEnd)) { bucket := add(bucket, 1) } {
                    mstore(0x00, bucket)
                    sstore(keccak256(0x00, 0x40), 0)
                }
                mstore(0x00, bucket)
            }
            let storageSlot := keccak256(0x00, 0x40)
            sstore(
                storageSlot, and(sload(storageSlot), not(shl(shift, shr(sub(256, amount), not(0)))))
            )
        }
    }
    function popCount(Bitmap storage bitmap, uint256 start, uint256 amount)
        internal
        view
        returns (uint256 count)
    {
        unchecked {
            uint256 bucket = start >> 8;
            uint256 shift = start & 0xff;
            if (!(amount + shift < 257)) {
                count = LibBit.popCount(bitmap.map[bucket] >> shift);
                uint256 bucketEnd = bucket + ((amount + shift) >> 8);
                amount = (amount + shift) & 0xff;
                shift = 0;
                for (++bucket; bucket != bucketEnd; ++bucket) {
                    count += LibBit.popCount(bitmap.map[bucket]);
                }
            }
            count += LibBit.popCount((bitmap.map[bucket] >> shift) << (256 - amount));
        }
    }
    function findLastSet(Bitmap storage bitmap, uint256 before)
        internal
        view
        returns (uint256 setBitIndex)
    {
        uint256 bucket;
        uint256 bucketBits;
        assembly {
            setBitIndex := not(0)
            bucket := shr(8, before)
            mstore(0x00, bucket)
            mstore(0x20, bitmap.slot)
            let offset := and(0xff, not(before)) 
            bucketBits := shr(offset, shl(offset, sload(keccak256(0x00, 0x40))))
            if iszero(bucketBits) {
                for {} bucket {} {
                    bucket := add(bucket, setBitIndex) 
                    mstore(0x00, bucket)
                    bucketBits := sload(keccak256(0x00, 0x40))
                    if bucketBits { break }
                }
            }
        }
        if (bucketBits != 0) {
            setBitIndex = (bucket << 8) | LibBit.fls(bucketBits);
            assembly {
                setBitIndex := or(setBitIndex, sub(0, gt(setBitIndex, before)))
            }
        }
    }
}