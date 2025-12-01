pragma solidity ^0.8.4;
import {ICrossDomainMessenger as Optimism_Bridge} from "../../vendor/optimism/ICrossDomainMessenger.sol";
import "../errors.sol";
library LibOptimism {
    function isCrossChain(address messenger) internal view returns (bool) {
        return msg.sender == messenger;
    }
    function crossChainSender(address messenger) internal view returns (address) {
        if (!isCrossChain(messenger)) revert NotCrossChainCall();
        return Optimism_Bridge(messenger).xDomainMessageSender();
    }
}