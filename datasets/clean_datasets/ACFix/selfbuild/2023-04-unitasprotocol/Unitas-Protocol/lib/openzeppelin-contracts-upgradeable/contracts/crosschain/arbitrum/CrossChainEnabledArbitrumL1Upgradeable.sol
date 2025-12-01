pragma solidity ^0.8.4;
import "../CrossChainEnabledUpgradeable.sol";
import "./LibArbitrumL1Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract CrossChainEnabledArbitrumL1Upgradeable is Initializable, CrossChainEnabledUpgradeable {
    address private immutable _bridge;
    constructor(address bridge) {
        _bridge = bridge;
    }
    function _isCrossChain() internal view virtual override returns (bool) {
        return LibArbitrumL1Upgradeable.isCrossChain(_bridge);
    }
    function _crossChainSender() internal view virtual override onlyCrossChain returns (address) {
        return LibArbitrumL1Upgradeable.crossChainSender(_bridge);
    }
    uint256[50] private __gap;
}