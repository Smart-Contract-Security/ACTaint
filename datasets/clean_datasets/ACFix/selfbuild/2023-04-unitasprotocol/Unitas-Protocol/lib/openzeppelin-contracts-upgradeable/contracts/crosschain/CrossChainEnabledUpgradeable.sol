pragma solidity ^0.8.4;
import "./errorsUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
abstract contract CrossChainEnabledUpgradeable is Initializable {
    function __CrossChainEnabled_init() internal onlyInitializing {
    }
    function __CrossChainEnabled_init_unchained() internal onlyInitializing {
    }
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
    uint256[50] private __gap;
}