pragma solidity ^0.8.9;
import "./ContextMock.sol";
import "../metatx/ERC2771Context.sol";
contract ERC2771ContextMock is ContextMock, ERC2771Context {
    constructor(address trustedForwarder) ERC2771Context(trustedForwarder) {
        emit Sender(_msgSender()); 
    }
    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }
    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }
}