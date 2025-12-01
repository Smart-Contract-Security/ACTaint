pragma solidity ^0.8.9;
contract Sink {
    event GotSignal(bytes data);
    fallback() external payable {
        emit GotSignal(msg.data);
    }
}