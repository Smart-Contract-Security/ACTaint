pragma solidity ^0.8.17;
abstract contract OwnableImpl {
    error Unauthorized();
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    address internal $owner;
    constructor() {}
    function __initOwnable(address owner_) internal virtual {
        emit OwnershipTransferred(address(0), owner_);
        $owner = owner_;
    }
    modifier onlyOwner() virtual {
        if (msg.sender != owner()) revert Unauthorized();
        _;
    }
    function transferOwnership(address owner_) public virtual onlyOwner {
        $owner = owner_;
        emit OwnershipTransferred(msg.sender, owner_);
    }
    function owner() public view virtual returns (address) {
        return $owner;
    }
}