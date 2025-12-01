pragma solidity ^0.8.4;
library LibPRNG {
    struct PRNG {
        uint256 state;
    }
    function seed(PRNG memory prng, uint256 state) internal pure {
        assembly {
            mstore(prng, state)
        }
    }
    function next(PRNG memory prng) internal pure returns (uint256 result) {
        assembly {
            result := keccak256(prng, 0x20)
            mstore(prng, result)
        }
    }
    function uniform(PRNG memory prng, uint256 upper) internal pure returns (uint256 result) {
        assembly {
            for {} 1 {} {
                result := keccak256(prng, 0x20)
                mstore(prng, result)
                if iszero(lt(result, mod(sub(0, upper), upper))) { break }
            }
            result := mod(result, upper)
        }
    }
    function shuffle(PRNG memory prng, uint256[] memory a) internal pure {
        assembly {
            let n := mload(a)
            let w := not(0)
            let mask := shr(128, w)
            if n {
                for { a := add(a, 0x20) } 1 {} {
                    let r := keccak256(prng, 0x20)
                    mstore(prng, r)
                    {
                        let j := add(a, shl(5, mod(shr(128, r), n)))
                        n := add(n, w) 
                        if iszero(n) { break }
                        let i := add(a, shl(5, n))
                        let t := mload(i)
                        mstore(i, mload(j))
                        mstore(j, t)
                    }
                    {
                        let j := add(a, shl(5, mod(and(r, mask), n)))
                        n := add(n, w) 
                        if iszero(n) { break }
                        let i := add(a, shl(5, n))
                        let t := mload(i)
                        mstore(i, mload(j))
                        mstore(j, t)
                    }
                }
            }
        }
    }
    function shuffle(PRNG memory prng, bytes memory a) internal pure {
        assembly {
            let n := mload(a)
            let w := not(0)
            let mask := shr(128, w)
            if n {
                let b := add(a, 0x01)
                for { a := add(a, 0x20) } 1 {} {
                    let r := keccak256(prng, 0x20)
                    mstore(prng, r)
                    {
                        let o := mod(shr(128, r), n)
                        n := add(n, w) 
                        if iszero(n) { break }
                        let t := mload(add(b, n))
                        mstore8(add(a, n), mload(add(b, o)))
                        mstore8(add(a, o), t)
                    }
                    {
                        let o := mod(and(r, mask), n)
                        n := add(n, w) 
                        if iszero(n) { break }
                        let t := mload(add(b, n))
                        mstore8(add(a, n), mload(add(b, o)))
                        mstore8(add(a, o), t)
                    }
                }
            }
        }
    }
}