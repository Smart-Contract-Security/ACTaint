pragma solidity ^0.8.4;
library SSTORE2 {
    uint256 internal constant DATA_OFFSET = 1;
    error DeploymentFailed();
    error InvalidPointer();
    error ReadOutOfBounds();
    function write(bytes memory data) internal returns (address pointer) {
        assembly {
            let originalDataLength := mload(data)
            let dataSize := add(originalDataLength, DATA_OFFSET)
            mstore(
                data,
                or(
                    0x61000080600a3d393df300,
                    shl(0x40, dataSize)
                )
            )
            pointer := create(0, add(data, 0x15), add(dataSize, 0xa))
            if iszero(pointer) {
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }
            mstore(data, originalDataLength)
        }
    }
    function writeDeterministic(bytes memory data, bytes32 salt)
        internal
        returns (address pointer)
    {
        assembly {
            let originalDataLength := mload(data)
            let dataSize := add(originalDataLength, DATA_OFFSET)
            mstore(data, or(0x61000080600a3d393df300, shl(0x40, dataSize)))
            pointer := create2(0, add(data, 0x15), add(dataSize, 0xa), salt)
            if iszero(pointer) {
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }
            mstore(data, originalDataLength)
        }
    }
    function initCodeHash(bytes memory data) internal pure returns (bytes32 hash) {
        assembly {
            let originalDataLength := mload(data)
            let dataSize := add(originalDataLength, DATA_OFFSET)
            mstore(data, or(0x61000080600a3d393df300, shl(0x40, dataSize)))
            hash := keccak256(add(data, 0x15), add(dataSize, 0xa))
            mstore(data, originalDataLength)
        }
    }
    function predictDeterministicAddress(bytes memory data, bytes32 salt, address deployer)
        internal
        pure
        returns (address predicted)
    {
        bytes32 hash = initCodeHash(data);
        assembly {
            mstore8(0x00, 0xff) 
            mstore(0x35, hash)
            mstore(0x01, shl(96, deployer))
            mstore(0x15, salt)
            predicted := keccak256(0x00, 0x55)
            mstore(0x35, 0)
        }
    }
    function read(address pointer) internal view returns (bytes memory data) {
        assembly {
            let pointerCodesize := extcodesize(pointer)
            if iszero(pointerCodesize) {
                mstore(0x00, 0x11052bb4)
                revert(0x1c, 0x04)
            }
            let size := sub(pointerCodesize, DATA_OFFSET)
            data := mload(0x40)
            mstore(0x40, add(data, and(add(size, 0x3f), 0xffe0)))
            mstore(data, size)
            mstore(add(add(data, 0x20), size), 0) 
            extcodecopy(pointer, add(data, 0x20), DATA_OFFSET, size)
        }
    }
    function read(address pointer, uint256 start) internal view returns (bytes memory data) {
        assembly {
            let pointerCodesize := extcodesize(pointer)
            if iszero(pointerCodesize) {
                mstore(0x00, 0x11052bb4)
                revert(0x1c, 0x04)
            }
            if iszero(gt(pointerCodesize, start)) {
                mstore(0x00, 0x84eb0dd1)
                revert(0x1c, 0x04)
            }
            let size := sub(pointerCodesize, add(start, DATA_OFFSET))
            data := mload(0x40)
            mstore(0x40, add(data, and(add(size, 0x3f), 0xffe0)))
            mstore(data, size)
            mstore(add(add(data, 0x20), size), 0) 
            extcodecopy(pointer, add(data, 0x20), add(start, DATA_OFFSET), size)
        }
    }
    function read(address pointer, uint256 start, uint256 end)
        internal
        view
        returns (bytes memory data)
    {
        assembly {
            let pointerCodesize := extcodesize(pointer)
            if iszero(pointerCodesize) {
                mstore(0x00, 0x11052bb4)
                revert(0x1c, 0x04)
            }
            if iszero(
                and(
                    gt(pointerCodesize, end), 
                    iszero(gt(start, end)) 
                )
            ) {
                mstore(0x00, 0x84eb0dd1)
                revert(0x1c, 0x04)
            }
            let size := sub(end, start)
            data := mload(0x40)
            mstore(0x40, add(data, and(add(size, 0x3f), 0xffe0)))
            mstore(data, size)
            mstore(add(add(data, 0x20), size), 0) 
            extcodecopy(pointer, add(data, 0x20), add(start, DATA_OFFSET), size)
        }
    }
}