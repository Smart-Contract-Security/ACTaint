pragma solidity ^0.8.4;
import { IAMBUpgradeable as AMB_Bridge } from "../../vendor/amb/IAMBUpgradeable.sol";
import "../errorsUpgradeable.sol";
library LibAMBUpgradeable {
    function isCrossChain(address bridge) internal view returns (bool) {
        return msg.sender == bridge;
    }
    function crossChainSender(address bridge) internal view returns (address) {
        if (!isCrossChain(bridge)) revert NotCrossChainCall();
        return AMB_Bridge(bridge).messageSender();
    }
}