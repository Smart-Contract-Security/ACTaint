pragma solidity >=0.8.0;
contract ReentrancyGuard {
    uint256 internal locked;
    modifier nonReentrant() virtual {
        require(locked == 1, "REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }
}