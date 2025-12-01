pragma solidity ^0.8.4;
import { ICrossDomainMessengerUpgradeable as Optimism_Bridge } from "../../vendor/optimism/ICrossDomainMessengerUpgradeable.sol";
import "../errorsUpgradeable.sol";
library LibOptimismUpgradeable {
    function isCrossChain(address messenger) internal view returns (bool) {
        return msg.sender == messenger;
    }
    function crossChainSender(address messenger) internal view returns (address) {
        if (!isCrossChain(messenger)) revert NotCrossChainCall();
        return Optimism_Bridge(messenger).xDomainMessageSender();
    }
}