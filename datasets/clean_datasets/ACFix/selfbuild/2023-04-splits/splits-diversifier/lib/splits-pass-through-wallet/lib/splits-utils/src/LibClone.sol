pragma solidity ^0.8.17;
library LibClone {
    error DeploymentFailed();
    uint256 private constant FREE_PTR = 0x40;
    uint256 private constant ZERO_PTR = 0x60;
    function clone(address implementation) internal returns (address instance) {
        assembly ("memory-safe") {
            let fp := mload(FREE_PTR)
            mstore(0x51, 0x5af43d3d93803e605757fd5bf3) 
            mstore(0x44, implementation) 
            mstore(0x30, 0x593da1005b3d3d3d3d363d3d37363d73) 
            mstore(0x20, 0x9e4ac34f21c619cefc926c8bd93b54bf5a39c7ab2127a895af1cc0691d7e3dff) 
            mstore(0x00, 0x60593d8160093d39f336602c57343d527f) 
            instance := create(0, 0x0f, 0x71)
            mstore(FREE_PTR, fp)
            mstore(ZERO_PTR, 0)
            if iszero(instance) {
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }
        }
    }
}