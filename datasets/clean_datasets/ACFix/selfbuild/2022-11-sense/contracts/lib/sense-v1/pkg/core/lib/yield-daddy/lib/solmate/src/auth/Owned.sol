pragma solidity >=0.8.0;
abstract contract Owned {
    event OwnerUpdated(address indexed user, address indexed newOwner);
    address public owner;
    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");
        _;
    }
    constructor(address _owner) {
        owner = _owner;
        emit OwnerUpdated(address(0), _owner);
    }
    function setOwner(address newOwner) public virtual onlyOwner {
        owner = newOwner;
        emit OwnerUpdated(msg.sender, newOwner);
    }
}