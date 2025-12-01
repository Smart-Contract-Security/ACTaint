pragma solidity ^0.8.4;
import "../CrossChainEnabled.sol";
import "./LibOptimism.sol";
abstract contract CrossChainEnabledOptimism is CrossChainEnabled {
    address private immutable _messenger;
    constructor(address messenger) {
        _messenger = messenger;
    }
    function _isCrossChain() internal view virtual override returns (bool) {
        return LibOptimism.isCrossChain(_messenger);
    }
    function _crossChainSender() internal view virtual override onlyCrossChain returns (address) {
        return LibOptimism.crossChainSender(_messenger);
    }
}