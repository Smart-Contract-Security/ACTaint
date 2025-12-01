pragma solidity ^0.8.4;
import "../CrossChainEnabledUpgradeable.sol";
import "./LibAMBUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";
contract CrossChainEnabledAMBUpgradeable is Initializable, CrossChainEnabledUpgradeable {
    address private immutable _bridge;
    constructor(address bridge) {
        _bridge = bridge;
    }
    function _isCrossChain() internal view virtual override returns (bool) {
        return LibAMBUpgradeable.isCrossChain(_bridge);
    }
    function _crossChainSender() internal view virtual override onlyCrossChain returns (address) {
        return LibAMBUpgradeable.crossChainSender(_bridge);
    }
    uint256[50] private __gap;
}