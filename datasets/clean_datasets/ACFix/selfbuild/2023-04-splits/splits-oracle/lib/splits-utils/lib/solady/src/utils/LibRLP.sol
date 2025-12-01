pragma solidity ^0.8.4;
library LibRLP {
    function computeAddress(address deployer, uint256 nonce)
        internal
        pure
        returns (address deployed)
    {
        assembly {
            for {} 1 {} {
                if iszero(gt(nonce, 0x7f)) {
                    mstore(0x00, deployer)
                    mstore8(0x0b, 0x94)
                    mstore8(0x0a, 0xd6)
                    mstore8(0x20, or(shl(7, iszero(nonce)), nonce))
                    deployed := keccak256(0x0a, 0x17)
                    break
                }
                let i := 8
                for {} shr(i, nonce) { i := add(i, 8) } {}
                i := shr(3, i)
                mstore(i, nonce)
                mstore(0x00, shl(8, deployer))
                mstore8(0x1f, add(0x80, i))
                mstore8(0x0a, 0x94)
                mstore8(0x09, add(0xd6, i))
                deployed := keccak256(0x09, add(0x17, i))
                break
            }
        }
    }
}