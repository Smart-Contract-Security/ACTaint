pragma solidity ^0.8.4;
library DynamicBufferLib {
    struct DynamicBuffer {
        bytes data;
    }
    function append(DynamicBuffer memory buffer, bytes memory data)
        internal
        pure
        returns (DynamicBuffer memory)
    {
        assembly {
            if mload(data) {
                let w := not(31)
                let bufferData := mload(buffer)
                let bufferDataLength := mload(bufferData)
                let newBufferDataLength := add(mload(data), bufferDataLength)
                let prime := 1621250193422201
                let capacity := mload(add(bufferData, w))
                capacity := mul(div(capacity, prime), iszero(mod(capacity, prime)))
                for {} iszero(lt(newBufferDataLength, capacity)) {} {
                    let newCapacity :=
                        and(add(capacity, add(or(capacity, newBufferDataLength), 32)), w)
                    if iszero(eq(mload(0x40), add(bufferData, add(0x40, capacity)))) {
                        let newBufferData := add(mload(0x40), 0x20)
                        mstore(0x40, add(newBufferData, add(0x40, newCapacity)))
                        mstore(buffer, newBufferData)
                        for { let o := and(add(bufferDataLength, 32), w) } 1 {} {
                            mstore(add(newBufferData, o), mload(add(bufferData, o)))
                            o := add(o, w) 
                            if iszero(o) { break }
                        }
                        mstore(add(newBufferData, w), mul(prime, newCapacity))
                        bufferData := newBufferData
                        break
                    }
                    mstore(0x40, add(bufferData, add(0x40, newCapacity)))
                    mstore(add(bufferData, w), mul(prime, newCapacity))
                    break
                }
                let output := add(bufferData, bufferDataLength)
                for { let o := and(add(mload(data), 32), w) } 1 {} {
                    mstore(add(output, o), mload(add(data, o)))
                    o := add(o, w) 
                    if iszero(o) { break }
                }
                mstore(add(add(bufferData, 0x20), newBufferDataLength), 0)
                mstore(bufferData, newBufferDataLength)
            }
        }
        return buffer;
    }
    function append(DynamicBuffer memory buffer, bytes memory data0, bytes memory data1)
        internal
        pure
        returns (DynamicBuffer memory)
    {
        return append(append(buffer, data0), data1);
    }
    function append(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2
    ) internal pure returns (DynamicBuffer memory) {
        return append(append(append(buffer, data0), data1), data2);
    }
    function append(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3
    ) internal pure returns (DynamicBuffer memory) {
        return append(append(append(append(buffer, data0), data1), data2), data3);
    }
    function append(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4
    ) internal pure returns (DynamicBuffer memory) {
        append(append(append(append(buffer, data0), data1), data2), data3);
        return append(buffer, data4);
    }
    function append(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4,
        bytes memory data5
    ) internal pure returns (DynamicBuffer memory) {
        append(append(append(append(buffer, data0), data1), data2), data3);
        return append(append(buffer, data4), data5);
    }
    function append(
        DynamicBuffer memory buffer,
        bytes memory data0,
        bytes memory data1,
        bytes memory data2,
        bytes memory data3,
        bytes memory data4,
        bytes memory data5,
        bytes memory data6
    ) internal pure returns (DynamicBuffer memory) {
        append(append(append(append(buffer, data0), data1), data2), data3);
        return append(append(append(buffer, data4), data5), data6);
    }
}