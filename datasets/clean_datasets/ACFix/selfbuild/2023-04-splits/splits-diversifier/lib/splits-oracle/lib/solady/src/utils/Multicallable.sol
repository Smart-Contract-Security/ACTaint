pragma solidity ^0.8.4;
abstract contract Multicallable {
    function multicall(bytes[] calldata data) public virtual returns (bytes[] memory) {
        assembly {
            mstore(0x00, 0x20)
            mstore(0x20, data.length) 
            if iszero(data.length) { return(0x00, 0x40) }
            let results := 0x40
            let end := shl(5, data.length)
            calldatacopy(0x40, data.offset, end)
            let resultsOffset := end
            end := add(results, end)
            for {} 1 {} {
                let o := add(data.offset, mload(results))
                let memPtr := add(resultsOffset, 0x40)
                calldatacopy(
                    memPtr,
                    add(o, 0x20), 
                    calldataload(o) 
                )
                if iszero(delegatecall(gas(), address(), memPtr, calldataload(o), 0x00, 0x00)) {
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }
                mstore(results, resultsOffset)
                results := add(results, 0x20)
                mstore(memPtr, returndatasize())
                returndatacopy(add(memPtr, 0x20), 0x00, returndatasize())
                resultsOffset :=
                    and(add(add(resultsOffset, returndatasize()), 0x3f), 0xffffffffffffffe0)
                if iszero(lt(results, end)) { break }
            }
            return(0x00, add(resultsOffset, 0x40))
        }
    }
}