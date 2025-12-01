pragma solidity >=0.6.9 <0.9.0;
import "./IBridge.sol";
interface IOutbox {
    event SendRootUpdated(bytes32 indexed blockHash, bytes32 indexed outputRoot);
    event OutBoxTransactionExecuted(
        address indexed to,
        address indexed l2Sender,
        uint256 indexed zero,
        uint256 transactionIndex
    );
    function rollup() external view returns (address); 
    function bridge() external view returns (IBridge); 
    function spent(uint256) external view returns (bytes32); 
    function roots(bytes32) external view returns (bytes32); 
    function OUTBOX_VERSION() external view returns (uint128); 
    function updateSendRoot(bytes32 sendRoot, bytes32 l2BlockHash) external;
    function l2ToL1Sender() external view returns (address);
    function l2ToL1Block() external view returns (uint256);
    function l2ToL1EthBlock() external view returns (uint256);
    function l2ToL1Timestamp() external view returns (uint256);
    function l2ToL1OutputId() external view returns (bytes32);
    function executeTransaction(
        bytes32[] calldata proof,
        uint256 index,
        address l2Sender,
        address to,
        uint256 l2Block,
        uint256 l1Block,
        uint256 l2Timestamp,
        uint256 value,
        bytes calldata data
    ) external;
    function executeTransactionSimulation(
        uint256 index,
        address l2Sender,
        address to,
        uint256 l2Block,
        uint256 l1Block,
        uint256 l2Timestamp,
        uint256 value,
        bytes calldata data
    ) external;
    function isSpent(uint256 index) external view returns (bool);
    function calculateItemHash(
        address l2Sender,
        address to,
        uint256 l2Block,
        uint256 l1Block,
        uint256 l2Timestamp,
        uint256 value,
        bytes calldata data
    ) external pure returns (bytes32);
    function calculateMerkleRoot(bytes32[] memory proof, uint256 path, bytes32 item) external pure returns (bytes32);
}