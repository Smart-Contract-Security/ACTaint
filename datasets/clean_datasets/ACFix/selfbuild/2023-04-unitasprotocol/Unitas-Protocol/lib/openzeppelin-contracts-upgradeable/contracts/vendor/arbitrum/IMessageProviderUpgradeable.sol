pragma solidity ^0.8.0;
interface IMessageProviderUpgradeable {
    event InboxMessageDelivered(uint256 indexed messageNum, bytes data);
    event InboxMessageDeliveredFromOrigin(uint256 indexed messageNum);
}