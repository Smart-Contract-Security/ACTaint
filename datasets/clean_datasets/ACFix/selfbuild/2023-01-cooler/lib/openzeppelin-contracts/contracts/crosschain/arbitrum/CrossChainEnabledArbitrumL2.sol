pragma solidity ^0.8.4;
import "../CrossChainEnabled.sol";
import "./LibArbitrumL2.sol";
abstract contract CrossChainEnabledArbitrumL2 is CrossChainEnabled {
    function _isCrossChain() internal view virtual override returns (bool) {
        return LibArbitrumL2.isCrossChain(LibArbitrumL2.ARBSYS);
    }
    function _crossChainSender() internal view virtual override onlyCrossChain returns (address) {
        return LibArbitrumL2.crossChainSender(LibArbitrumL2.ARBSYS);
    }
}