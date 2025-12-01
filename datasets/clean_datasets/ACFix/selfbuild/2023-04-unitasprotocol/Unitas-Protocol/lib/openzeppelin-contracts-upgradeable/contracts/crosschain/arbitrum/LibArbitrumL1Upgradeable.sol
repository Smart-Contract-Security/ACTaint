pragma solidity ^0.8.4;
import { IBridgeUpgradeable as ArbitrumL1_Bridge } from "../../vendor/arbitrum/IBridgeUpgradeable.sol";
import { IInboxUpgradeable as ArbitrumL1_Inbox } from "../../vendor/arbitrum/IInboxUpgradeable.sol";
import { IOutboxUpgradeable as ArbitrumL1_Outbox } from "../../vendor/arbitrum/IOutboxUpgradeable.sol";
import "../errorsUpgradeable.sol";
library LibArbitrumL1Upgradeable {
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