pragma solidity ^0.8.4;
import "../CrossChainEnabledUpgradeable.sol";
import "./LibOptimismUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract CrossChainEnabledOptimismUpgradeable is Initializable, CrossChainEnabledUpgradeable {
    address private immutable _messenger;
    constructor(address messenger) {
        _messenger = messenger;
    }
    function _isCrossChain() internal view virtual override returns (bool) {
        return LibOptimismUpgradeable.isCrossChain(_messenger);
    }
    function _crossChainSender() internal view virtual override onlyCrossChain returns (address) {
        return LibOptimismUpgradeable.crossChainSender(_messenger);
    }
    uint256[50] private __gap;
}