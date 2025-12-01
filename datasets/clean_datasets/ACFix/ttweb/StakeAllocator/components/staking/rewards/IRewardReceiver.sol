pragma solidity ^0.8.9;
interface IRewardReceiver {
    function onRewardReceived(
        uint8 subjectType,
        uint256 subject,
        uint256 amount
    ) external;
}