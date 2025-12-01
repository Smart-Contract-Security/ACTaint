pragma solidity 0.8.11;
import { Divider } from "../../Divider.sol";
contract Factory {
    event Deployed(address addr, uint256 salt);
    function getBytecode(address _owner, uint256 _foo) public pure returns (bytes memory) {
        bytes memory bytecode = type(Divider).creationCode;
        return abi.encodePacked(bytecode, abi.encode(_owner, _foo));
    }
    function getAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }
    function deploy(bytes memory bytecode, uint256 _salt) public payable {
        address addr;
        assembly {
            addr := create2(
                callvalue(), 
                add(bytecode, 0x20),
                mload(bytecode), 
                _salt 
            )
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit Deployed(addr, _salt);
    }
}