pragma solidity ^0.8.4;
import {IAMB as AMB_Bridge} from "../../vendor/amb/IAMB.sol";
import "../errors.sol";
library LibAMB {
    function isCrossChain(address bridge) internal view returns (bool) {
        return msg.sender == bridge;
    }
    function crossChainSender(address bridge) internal view returns (address) {
        if (!isCrossChain(bridge)) revert NotCrossChainCall();
        return AMB_Bridge(bridge).messageSender();
    }
}