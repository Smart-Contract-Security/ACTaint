pragma solidity >=0.8.0;
abstract contract ReentrancyGuard {
    uint256 private locked = 1;
    modifier nonReentrant() virtual {
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }
}