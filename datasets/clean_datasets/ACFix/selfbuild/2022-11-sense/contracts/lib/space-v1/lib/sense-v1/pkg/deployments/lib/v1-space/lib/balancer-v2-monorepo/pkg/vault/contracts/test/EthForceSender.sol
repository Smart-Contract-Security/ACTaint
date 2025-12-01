pragma solidity ^0.7.0;
contract EthForceSender {
    constructor(address payable recipient) payable {
        selfdestruct(recipient);
    }
}