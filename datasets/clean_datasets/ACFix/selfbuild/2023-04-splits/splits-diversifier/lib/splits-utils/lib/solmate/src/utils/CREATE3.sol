pragma solidity >=0.8.0;
import {Bytes32AddressLib} from "./Bytes32AddressLib.sol";
library CREATE3 {
    using Bytes32AddressLib for bytes32;
    bytes internal constant PROXY_BYTECODE = hex"67_36_3d_3d_37_36_3d_34_f0_3d_52_60_08_60_18_f3";
    bytes32 internal constant PROXY_BYTECODE_HASH = keccak256(PROXY_BYTECODE);
    function deploy(
        bytes32 salt,
        bytes memory creationCode,
        uint256 value
    ) internal returns (address deployed) {
        bytes memory proxyChildBytecode = PROXY_BYTECODE;
        address proxy;
        assembly {
            proxy := create2(0, add(proxyChildBytecode, 32), mload(proxyChildBytecode), salt)
        }
        require(proxy != address(0), "DEPLOYMENT_FAILED");
        deployed = getDeployed(salt);
        (bool success, ) = proxy.call{value: value}(creationCode);
        require(success && deployed.code.length != 0, "INITIALIZATION_FAILED");
    }
    function getDeployed(bytes32 salt) internal view returns (address) {
        address proxy = keccak256(
            abi.encodePacked(
                bytes1(0xFF),
                address(this),
                salt,
                PROXY_BYTECODE_HASH
            )
        ).fromLast20Bytes();
        return
            keccak256(
                abi.encodePacked(
                    hex"d6_94",
                    proxy,
                    hex"01" 
                )
            ).fromLast20Bytes();
    }
}