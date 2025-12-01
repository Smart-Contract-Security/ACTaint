pragma solidity >=0.8.0;
library MerkleProofLib {
    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        assembly {
            let computedHash := leaf 
            let data := proof.offset
            for {
                let end := add(data, shl(5, proof.length))
            } lt(data, end) {
                data := add(data, 32) 
            } {
                let loadedData := calldataload(data)
                let computedHashSlot := shl(5, gt(computedHash, loadedData))
                mstore(computedHashSlot, computedHash)
                mstore(xor(computedHashSlot, 32), loadedData)
                computedHash := keccak256(0, 64) 
            }
            isValid := eq(computedHash, root) 
        }
    }
}