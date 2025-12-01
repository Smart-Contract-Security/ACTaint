pragma solidity ^0.4.24;
contract Nobody {
    function die() public {
        selfdestruct(msg.sender);
    }
}
