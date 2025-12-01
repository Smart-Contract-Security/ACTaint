pragma solidity ^0.8.4;
library CREATE3 {
    error DeploymentFailed();
    error InitializationFailed();
    uint256 private constant _PROXY_BYTECODE = 0x67363d3d37363d34f03d5260086018f3;
    bytes32 private constant _PROXY_BYTECODE_HASH =
        0x21c35dbe1b344a2488cf3321d6ce542f8e9f305544ff09e4993a62319a497c1f;
    function deploy(bytes32 salt, bytes memory creationCode, uint256 value)
        internal
        returns (address deployed)
    {
        assembly {
            mstore(0x00, _PROXY_BYTECODE)
            let proxy := create2(0, 0x10, 0x10, salt)
            if iszero(proxy) {
                mstore(0x00, 0x30116425)
                revert(0x1c, 0x04)
            }
            mstore(0x14, proxy)
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01)
            deployed := keccak256(0x1e, 0x17)
            if iszero(
                call(
                    gas(), 
                    proxy, 
                    value, 
                    add(creationCode, 0x20), 
                    mload(creationCode), 
                    0x00, 
                    0x00 
                )
            ) {
                mstore(0x00, 0x19b991a8)
                revert(0x1c, 0x04)
            }
            if iszero(extcodesize(deployed)) {
                mstore(0x00, 0x19b991a8)
                revert(0x1c, 0x04)
            }
        }
    }
    function getDeployed(bytes32 salt) internal view returns (address deployed) {
        assembly {
            let m := mload(0x40)
            mstore(0x00, address())
            mstore8(0x0b, 0xff)
            mstore(0x20, salt)
            mstore(0x40, _PROXY_BYTECODE_HASH)
            mstore(0x14, keccak256(0x0b, 0x55))
            mstore(0x40, m)
            mstore(0x00, 0xd694)
            mstore8(0x34, 0x01)
            deployed := keccak256(0x1e, 0x17)
        }
    }
}