pragma solidity >=0.8.0;
library LibString {
    function toString(uint256 n) internal pure returns (string memory str) {
        if (n == 0) return "0"; 
        assembly {
            let k := 78 
            str := mload(0x40)
            mstore(str, k)
            mstore(0x40, add(str, 128))
            for {} n {} {
                let char := add(48, mod(n, 10))
                mstore(add(str, k), char)
                k := sub(k, 1)
                n := div(n, 10)
            }
            str := add(str, k)
            mstore(str, sub(78, k))
        }
    }
}