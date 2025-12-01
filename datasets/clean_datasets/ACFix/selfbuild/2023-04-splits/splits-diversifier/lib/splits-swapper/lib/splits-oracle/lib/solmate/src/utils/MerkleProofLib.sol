pragma solidity >=0.8.0;
library MerkleProofLib {
    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        assembly {
            if proof.length {
                let end := add(proof.offset, shl(5, proof.length))
                let offset := proof.offset
                for {} 1 {} {
                    let leafSlot := shl(5, gt(leaf, calldataload(offset)))
                    mstore(leafSlot, leaf)
                    mstore(xor(leafSlot, 32), calldataload(offset))
                    leaf := keccak256(0, 64) 
                    offset := add(offset, 32) 
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf, root) 
        }
    }
}