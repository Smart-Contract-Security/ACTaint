pragma solidity ^0.5.2;
import "./Admin.sol";
contract SuperOperators is Admin {
    mapping(address => bool) internal _superOperators;
    event SuperOperator(address superOperator, bool enabled);
    function setSuperOperator(address superOperator, bool enabled) external {
        require(
            msg.sender == _admin,
            "only admin is allowed to add super operators"
        );
        _superOperators[superOperator] = enabled;
        emit SuperOperator(superOperator, enabled);
    }
    function isSuperOperator(address who) public view returns (bool) {
        return _superOperators[who];
    }
}