pragma solidity ^0.8.4;
import {IBridge as ArbitrumL1_Bridge} from "../../vendor/arbitrum/IBridge.sol";
import {IInbox as ArbitrumL1_Inbox} from "../../vendor/arbitrum/IInbox.sol";
import {IOutbox as ArbitrumL1_Outbox} from "../../vendor/arbitrum/IOutbox.sol";
import "../errors.sol";
library LibArbitrumL1 {
    function isCrossChain(address bridge) internal view returns (bool) {
        return msg.sender == bridge;
    }
    function crossChainSender(address bridge) internal view returns (address) {
        if (!isCrossChain(bridge)) revert NotCrossChainCall();
        address sender = ArbitrumL1_Outbox(ArbitrumL1_Bridge(bridge).activeOutbox()).l2ToL1Sender();
        require(sender != address(0), "LibArbitrumL1: system messages without sender");
        return sender;
    }
}