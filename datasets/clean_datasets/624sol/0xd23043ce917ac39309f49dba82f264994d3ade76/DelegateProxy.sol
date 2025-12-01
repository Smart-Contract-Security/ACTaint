pragma solidity ^0.4.24;
contract DelegateProxy {
  function delegatedFwd(address _dst, bytes _calldata) internal {
    require(isContract(_dst));
    assembly {
      let result := delegatecall(sub(gas, 10000), _dst, add(_calldata, 0x20), mload(_calldata), 0, 0)
      let size := returndatasize
      let ptr := mload(0x40)
      returndatacopy(ptr, 0, size)
      switch result case 0 {revert(ptr, size)}
      default {return (ptr, size)}
    }
  }
  function isContract(address _target) internal view returns (bool) {
    uint256 size;
    assembly {size := extcodesize(_target)}
    return size > 0;
  }
}