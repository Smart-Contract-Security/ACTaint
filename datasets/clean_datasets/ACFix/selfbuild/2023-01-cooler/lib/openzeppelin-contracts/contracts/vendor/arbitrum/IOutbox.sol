pragma solidity ^0.8.0;
interface IOutbox {
    event OutboxEntryCreated(
        uint256 indexed batchNum,
        uint256 outboxEntryIndex,
        bytes32 outputRoot,
        uint256 numInBatch
    );
    event OutBoxTransactionExecuted(
        address indexed destAddr,
        address indexed l2Sender,
        uint256 indexed outboxEntryIndex,
        uint256 transactionIndex
    );
    function l2ToL1Sender() external view returns (address);
    function l2ToL1Block() external view returns (uint256);
    function l2ToL1EthBlock() external view returns (uint256);
    function l2ToL1Timestamp() external view returns (uint256);
    function l2ToL1BatchNum() external view returns (uint256);
    function l2ToL1OutputId() external view returns (bytes32);
    function processOutgoingMessages(bytes calldata sendsData, uint256[] calldata sendLengths) external;
    function outboxEntryExists(uint256 batchNum) external view returns (bool);
}