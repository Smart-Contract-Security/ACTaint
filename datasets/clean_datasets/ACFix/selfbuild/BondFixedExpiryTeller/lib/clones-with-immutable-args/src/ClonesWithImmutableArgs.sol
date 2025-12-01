pragma solidity ^0.8.4;
library ClonesWithImmutableArgs {
    error CreateFail();
    function clone(address implementation, bytes memory data)
        internal
        returns (address instance)
    {
        unchecked {
            uint256 extraLength = data.length + 2; 
            uint256 creationSize = 0x43 + extraLength;
            uint256 runSize = creationSize - 11;
            uint256 dataPtr;
            uint256 ptr;
            assembly {
                ptr := mload(0x40)
                mstore(
                    ptr,
                    0x3d61000000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x02), shl(240, runSize)) 
                mstore(
                    add(ptr, 0x04),
                    0x80600b3d3981f300000000000000000000000000000000000000000000000000
                )
                mstore(
                    add(ptr, 0x0b),
                    0x363d3d3761000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x10), shl(240, extraLength))
                mstore(
                    add(ptr, 0x12),
                    0x603836393d3d3d36610000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x1b), shl(240, extraLength))
                mstore(
                    add(ptr, 0x1d),
                    0x013d730000000000000000000000000000000000000000000000000000000000
                )
                mstore(add(ptr, 0x20), shl(0x60, implementation))
                mstore(
                    add(ptr, 0x34),
                    0x5af43d82803e903d91603657fd5bf30000000000000000000000000000000000
                )
            }
            extraLength -= 2;
            uint256 counter = extraLength;
            uint256 copyPtr = ptr + 0x43;
            assembly {
                dataPtr := add(data, 32)
            }
            for (; counter >= 32; counter -= 32) {
                assembly {
                    mstore(copyPtr, mload(dataPtr))
                }
                copyPtr += 32;
                dataPtr += 32;
            }
            uint256 mask = ~(256**(32 - counter) - 1);
            assembly {
                mstore(copyPtr, and(mload(dataPtr), mask))
            }
            copyPtr += counter;
            assembly {
                mstore(copyPtr, shl(240, extraLength))
            }
            assembly {
                instance := create(0, ptr, creationSize)
            }
            if (instance == address(0)) {
                revert CreateFail();
            }
        }
    }
}