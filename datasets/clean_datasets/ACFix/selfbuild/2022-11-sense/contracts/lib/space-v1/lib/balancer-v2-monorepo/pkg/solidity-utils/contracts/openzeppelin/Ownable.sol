pragma solidity ^0.7.0;
import "../helpers/BalancerErrors.sol";
abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        _require(owner() == msg.sender, Errors.CALLER_IS_NOT_OWNER);
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        _require(newOwner != address(0), Errors.NEW_OWNER_IS_ZERO);
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}