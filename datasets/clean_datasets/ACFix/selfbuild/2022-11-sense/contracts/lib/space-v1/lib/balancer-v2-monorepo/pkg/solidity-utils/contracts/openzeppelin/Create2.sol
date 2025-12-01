pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
library Create2 {
    function deploy(uint256 amount, bytes32 salt, bytes memory bytecode) internal returns (address) {
        address addr;
        require(address(this).balance >= amount, 'CREATE2_INSUFFICIENT_BALANCE');
        require(bytecode.length != 0, 'CREATE2_BYTECODE_ZERO');
        assembly {
            addr := create2(amount, add(bytecode, 0x20), mload(bytecode), salt)
        }
        require(addr != address(0), 'CREATE2_DEPLOY_FAILED');
        return addr;
    }
    function computeAddress(bytes32 salt, bytes32 bytecodeHash) internal view returns (address) {
        return computeAddress(salt, bytecodeHash, address(this));
    }
    function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address) {
        bytes32 _data = keccak256(
            abi.encodePacked(bytes1(0xff), deployer, salt, bytecodeHash)
        );
        return address(uint256(_data));
    }
}