pragma solidity ^0.8.4;
import { IArbSysUpgradeable as ArbitrumL2_Bridge } from "../../vendor/arbitrum/IArbSysUpgradeable.sol";
import "../errorsUpgradeable.sol";
library LibArbitrumL2Upgradeable {
    address public constant ARBSYS = 0x0000000000000000000000000000000000000064;
    function isCrossChain(address arbsys) internal view returns (bool) {
        return ArbitrumL2_Bridge(arbsys).wasMyCallersAddressAliased();
    }
    function crossChainSender(address arbsys) internal view returns (address) {
        if (!isCrossChain(arbsys)) revert NotCrossChainCall();
        return ArbitrumL2_Bridge(arbsys).myCallersAddressWithoutAliasing();
    }
}