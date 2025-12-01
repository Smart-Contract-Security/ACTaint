pragma solidity ^0.8.4;
library MerkleProofLib {
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf)
        internal
        pure
        returns (bool isValid)
    {
        assembly {
            if mload(proof) {
                let offset := add(proof, 0x20)
                let end := add(offset, shl(5, mload(proof)))
                for {} 1 {} {
                    let scratch := shl(5, gt(leaf, mload(offset)))
                    mstore(scratch, leaf)
                    mstore(xor(scratch, 0x20), mload(offset))
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf, root)
        }
    }
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf)
        internal
        pure
        returns (bool isValid)
    {
        assembly {
            if proof.length {
                let end := add(proof.offset, shl(5, proof.length))
                let offset := proof.offset
                for {} 1 {} {
                    let scratch := shl(5, gt(leaf, calldataload(offset)))
                    mstore(scratch, leaf)
                    mstore(xor(scratch, 0x20), calldataload(offset))
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf, root)
        }
    }
    function verifyMultiProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32[] memory leafs,
        bool[] memory flags
    ) internal pure returns (bool isValid) {
        assembly {
            let leafsLength := mload(leafs)
            let proofLength := mload(proof)
            let flagsLength := mload(flags)
            leafs := add(0x20, leafs)
            proof := add(0x20, proof)
            flags := add(0x20, flags)
            for {} eq(add(leafsLength, proofLength), add(flagsLength, 1)) {} {
                if iszero(flagsLength) {
                    isValid := eq(mload(xor(leafs, mul(xor(proof, leafs), proofLength))), root)
                    break
                }
                let hashesFront := mload(0x40)
                leafsLength := shl(5, leafsLength)
                for { let i := 0 } iszero(eq(i, leafsLength)) { i := add(i, 0x20) } {
                    mstore(add(hashesFront, i), mload(add(leafs, i)))
                }
                let hashesBack := add(hashesFront, leafsLength)
                flagsLength := add(hashesBack, shl(5, flagsLength))
                for {} 1 {} {
                    let a := mload(hashesFront)
                    let b := mload(add(hashesFront, 0x20))
                    hashesFront := add(hashesFront, 0x40)
                    if iszero(mload(flags)) {
                        b := mload(proof)
                        proof := add(proof, 0x20)
                        hashesFront := sub(hashesFront, 0x20)
                    }
                    flags := add(flags, 0x20)
                    let scratch := shl(5, gt(a, b))
                    mstore(scratch, a)
                    mstore(xor(scratch, 0x20), b)
                    mstore(hashesBack, keccak256(0x00, 0x40))
                    hashesBack := add(hashesBack, 0x20)
                    if iszero(lt(hashesBack, flagsLength)) { break }
                }
                isValid := eq(mload(sub(hashesBack, 0x20)), root)
                break
            }
        }
    }
    function verifyMultiProofCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32[] calldata leafs,
        bool[] calldata flags
    ) internal pure returns (bool isValid) {
        assembly {
            for {} eq(add(leafs.length, proof.length), add(flags.length, 1)) {} {
                if iszero(flags.length) {
                    isValid := eq(
                        calldataload(
                            xor(leafs.offset, mul(xor(proof.offset, leafs.offset), proof.length))
                        ),
                        root
                    )
                    break
                }
                let hashesFront := mload(0x40)
                calldatacopy(hashesFront, leafs.offset, shl(5, leafs.length))
                let hashesBack := add(hashesFront, shl(5, leafs.length))
                flags.length := add(hashesBack, shl(5, flags.length))
                for {} 1 {} {
                    let a := mload(hashesFront)
                    let b := mload(add(hashesFront, 0x20))
                    hashesFront := add(hashesFront, 0x40)
                    if iszero(calldataload(flags.offset)) {
                        b := calldataload(proof.offset)
                        proof.offset := add(proof.offset, 0x20)
                        hashesFront := sub(hashesFront, 0x20)
                    }
                    flags.offset := add(flags.offset, 0x20)
                    let scratch := shl(5, gt(a, b))
                    mstore(scratch, a)
                    mstore(xor(scratch, 0x20), b)
                    mstore(hashesBack, keccak256(0x00, 0x40))
                    hashesBack := add(hashesBack, 0x20)
                    if iszero(lt(hashesBack, flags.length)) { break }
                }
                isValid := eq(mload(sub(hashesBack, 0x20)), root)
                break
            }
        }
    }
    function emptyProof() internal pure returns (bytes32[] calldata proof) {
        assembly {
            proof.length := 0
        }
    }
    function emptyLeafs() internal pure returns (bytes32[] calldata leafs) {
        assembly {
            leafs.length := 0
        }
    }
    function emptyFlags() internal pure returns (bool[] calldata flags) {
        assembly {
            flags.length := 0
        }
    }
}