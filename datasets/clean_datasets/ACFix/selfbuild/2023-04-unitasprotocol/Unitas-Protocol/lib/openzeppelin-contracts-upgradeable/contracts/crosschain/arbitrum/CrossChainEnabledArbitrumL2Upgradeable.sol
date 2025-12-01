pragma solidity ^0.8.4;
import "../CrossChainEnabledUpgradeable.sol";
import "./LibArbitrumL2Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";
abstract contract CrossChainEnabledArbitrumL2Upgradeable is Initializable, CrossChainEnabledUpgradeable {
    function __CrossChainEnabledArbitrumL2_init() internal onlyInitializing {
    }
    function __CrossChainEnabledArbitrumL2_init_unchained() internal onlyInitializing {
    }
    function _isCrossChain() internal view virtual override returns (bool) {
        return LibArbitrumL2Upgradeable.isCrossChain(LibArbitrumL2Upgradeable.ARBSYS);
    }
    function _crossChainSender() internal view virtual override onlyCrossChain returns (address) {
        return LibArbitrumL2Upgradeable.crossChainSender(LibArbitrumL2Upgradeable.ARBSYS);
    }
    uint256[50] private __gap;
}