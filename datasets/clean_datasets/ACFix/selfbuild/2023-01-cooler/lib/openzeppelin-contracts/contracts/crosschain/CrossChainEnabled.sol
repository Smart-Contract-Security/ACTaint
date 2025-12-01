pragma solidity ^0.8.4;
import "./errors.sol";
abstract contract CrossChainEnabled {
    modifier onlyCrossChain() {
        if (!_isCrossChain()) revert NotCrossChainCall();
        _;
    }
    modifier onlyCrossChainSender(address expected) {
        address actual = _crossChainSender();
        if (expected != actual) revert InvalidCrossChainSender(actual, expected);
        _;
    }
    function _isCrossChain() internal view virtual returns (bool);
    function _crossChainSender() internal view virtual returns (address);
}