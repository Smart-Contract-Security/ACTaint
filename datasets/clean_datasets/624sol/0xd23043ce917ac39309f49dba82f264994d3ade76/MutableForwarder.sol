pragma solidity ^0.4.24;
import "./DelegateProxy.sol";
import "./DSAuth.sol";
contract MutableForwarder is DelegateProxy, DSAuth {
  address public target = 0xBEeFbeefbEefbeEFbeEfbEEfBEeFbeEfBeEfBeef;
  function setTarget(address _target) public auth {
    target = _target;
  }
  function() payable {
    delegatedFwd(target, msg.data);
  }
}